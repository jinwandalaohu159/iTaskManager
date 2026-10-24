import CSystem
import Darwin
import Foundation

final class ProcessSampler {
    private var previous: [pid_t: ProcessCounters] = [:]
    private var previousTime: UInt64 = 0
    private var paths: [pid_t: String] = [:]
    private var owners: [pid_t: uid_t] = [:]
    private let helper = HelperCounterReader()
    private var ledger = EnergyLedger()
    private let timebase: (numer: UInt64, denom: UInt64) = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return (UInt64(info.numer), UInt64(info.denom))
    }()

    /// How far back `ProcessStats.energy` reaches; nil before the first reading.
    var energySpan: TimeInterval? { ledger.span() }

    /// True when the counters are too old to produce meaningful rates.
    func isStale(after seconds: Double) -> Bool {
        previousTime == 0 || machToSeconds(mach_absolute_time() - previousTime) > seconds
    }

    /// Reads every process. With `privileged`, counters come from the root helper so system
    /// and other users' processes are included; without it, or if the helper doesn't answer,
    /// only processes this user may read get figures.
    func sample(privileged: Bool = false) -> [ProcessStats] {
        let now = mach_absolute_time()
        let elapsed = previousTime == 0 ? 0 : machToSeconds(now - previousTime)
        previousTime = now

        let pids = Self.allPIDs()
        guard !pids.isEmpty else { return [] }
        let counters = readCounters(pids, privileged: privileged)
        var livePaths: [pid_t: String] = [:]
        var liveOwners: [pid_t: uid_t] = [:]

        var result = pids.map { pid in
            var stats = ProcessStats(
                id: pid,
                name: ProcessIdentity.name(of: pid),
                path: paths[pid] ?? ProcessIdentity.path(of: pid),
                responsiblePID: responsibility_get_pid_responsible_for_pid(pid)
            )
            stats.uid = owners[pid] ?? ProcessIdentity.owner(of: pid)
            livePaths[pid] = stats.path
            liveOwners[pid] = stats.uid
            if stats.name.isEmpty {
                stats.name = stats.path.map { String($0.split(separator: "/").last ?? "") } ?? "pid \(pid)"
            }
            if let current = counters[pid] {
                stats.memory = current.footprint
                applyRates(to: &stats, current: current, elapsed: elapsed)
            }
            return stats
        }

        let responsible = Dictionary(result.map { ($0.id, $0.responsiblePID) }, uniquingKeysWith: { a, _ in a })
        ledger.record(counters, responsible: responsible, alive: Set(pids))
        let energies = ledger.energies(counters)
        for i in result.indices {
            result[i].energy = energies[result[i].id]
        }

        previous = counters
        paths = livePaths
        owners = liveOwners
        return result
    }

    /// Keeps the hour of energy figures going while processes aren't being sampled: reads
    /// just the counters, every few minutes.
    func checkpointEnergyIfDue(privileged: Bool) {
        guard ledger.isCheckpointDue else { return }
        let pids = Self.allPIDs()
        let counters = readCounters(pids, privileged: privileged)
        let responsible = Dictionary(uniqueKeysWithValues: counters.keys.map { ($0, responsibility_get_pid_responsible_for_pid($0)) })
        ledger.record(counters, responsible: responsible, alive: Set(pids))
    }

    /// Every readable process's counters: from the helper when `privileged` and it answers,
    /// otherwise whichever this user may read.
    private func readCounters(_ pids: [pid_t], privileged: Bool) -> [pid_t: ProcessCounters] {
        let fromHelper = privileged ? helper.read() : nil
        var counters: [pid_t: ProcessCounters] = [:]
        counters.reserveCapacity(pids.count)
        for pid in pids {
            if let c = fromHelper?[pid] ?? ProcessCounters.read(pid) { counters[pid] = c }
        }
        return counters
    }

    /// Rates since the previous sample. A process seen for the first time (or a reused pid)
    /// starts at zero rather than counting everything since it launched.
    private func applyRates(to stats: inout ProcessStats, current: ProcessCounters, elapsed: Double) {
        guard elapsed > 0 else { return }
        guard let old = previous[stats.id], old.startTime == current.startTime else {
            stats.timeRate = 0
            stats.cycleRate = 0
            stats.power = 0
            stats.disk = 0
            return
        }
        let cpuSeconds = machToSeconds(current.cpuTime &- old.cpuTime)
        let cycles = Double(current.cycles &- old.cycles)
        stats.timeRate = cpuSeconds / elapsed
        stats.pTimeRate = min(machToSeconds(current.pCoreTime &- old.pCoreTime), cpuSeconds) / elapsed
        stats.cycleRate = cycles / elapsed
        stats.pCycleRate = min(Double(current.pCycles &- old.pCycles), cycles) / elapsed
        stats.power = Double(current.energy &- old.energy) / 1e9 / elapsed
        stats.disk = Double(current.diskBytes &- old.diskBytes) / elapsed
    }

    private static func allPIDs() -> [pid_t] {
        var pids = [pid_t](repeating: 0, count: 4096)
        let bytes = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        guard bytes > 0 else { return [] }
        return pids.prefix(min(Int(bytes), pids.count)).filter { $0 > 0 }
    }

    private func machToSeconds(_ ticks: UInt64) -> Double {
        Double(ticks) * Double(timebase.numer) / Double(timebase.denom) / 1e9
    }
}
