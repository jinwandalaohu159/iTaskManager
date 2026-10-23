import CSystem
import Darwin

final class ProcessSampler {
    private var previous: [pid_t: ProcessCounters] = [:]
    private var previousTime: UInt64 = 0
    private var paths: [pid_t: String] = [:]
    /// Whether the last `sample(privileged:)` got its counters from the helper.
    private(set) var lastSampleWasPrivileged = false
    private var owners: [pid_t: uid_t] = [:]
    private let helper = HelperCounterReader()
    private let timebase: (numer: UInt64, denom: UInt64) = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return (UInt64(info.numer), UInt64(info.denom))
    }()

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

        var pids = [pid_t](repeating: 0, count: 4096)
        let bytes = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        guard bytes > 0 else { return [] }
        let count = min(Int(bytes), pids.count)

        var result: [ProcessStats] = []
        result.reserveCapacity(count)
        var current: [pid_t: ProcessCounters] = [:]
        current.reserveCapacity(count)
        var livePaths: [pid_t: String] = [:]
        var liveOwners: [pid_t: uid_t] = [:]
        let fromHelper = privileged ? helper.read() : nil
        lastSampleWasPrivileged = fromHelper != nil

        for pid in pids.prefix(count) where pid > 0 {
            var stats = ProcessStats(
                id: pid,
                name: ProcessIdentity.name(of: pid),
                path: nil,
                responsiblePID: responsibility_get_pid_responsible_for_pid(pid)
            )

            if let counters = fromHelper?[pid] ?? ProcessCounters.read(pid) {
                current[pid] = counters
                stats.memory = counters.footprint
                if elapsed > 0, let old = previous[pid], old.startTime == counters.startTime {
                    let cpuSeconds = machToSeconds(counters.cpuTime &- old.cpuTime)
                    let cycles = Double(counters.cycles &- old.cycles)
                    stats.timeRate = cpuSeconds / elapsed
                    stats.pTimeRate = min(machToSeconds(counters.pCoreTime &- old.pCoreTime), cpuSeconds) / elapsed
                    stats.cycleRate = cycles / elapsed
                    stats.pCycleRate = min(Double(counters.pCycles &- old.pCycles), cycles) / elapsed
                    stats.power = Double(counters.energy &- old.energy) / 1e9 / elapsed
                    stats.disk = Double(counters.diskBytes &- old.diskBytes) / elapsed
                } else if elapsed > 0 {
                    stats.timeRate = 0
                    stats.cycleRate = 0
                    stats.power = 0
                    stats.disk = 0
                }
            }

            stats.path = paths[pid] ?? ProcessIdentity.path(of: pid)
            livePaths[pid] = stats.path
            stats.uid = owners[pid] ?? ProcessIdentity.owner(of: pid)
            liveOwners[pid] = stats.uid
            if stats.name.isEmpty {
                stats.name = stats.path.map { String($0.split(separator: "/").last ?? "") } ?? "pid \(pid)"
            }
            result.append(stats)
        }

        previous = current
        paths = livePaths
        owners = liveOwners
        return result
    }

    private func machToSeconds(_ ticks: UInt64) -> Double {
        Double(ticks) * Double(timebase.numer) / Double(timebase.denom) / 1e9
    }
}
