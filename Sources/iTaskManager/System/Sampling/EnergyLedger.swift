import Darwin
import Foundation

/// Energy each process used over roughly the last hour.
///
/// The kernel keeps a running total of every process's energy since it started, so the
/// energy over a window is the total now minus the total at the window's start. The ledger
/// keeps a checkpoint of those totals every few minutes and measures from the oldest one
/// still inside the hour; checkpoints are cheap, so they continue while no window is open.
///
/// A helper process that quits within the hour still counts: its energy up to its last
/// reading is credited to the process responsible for it (the app it belongs to).
struct EnergyLedger {
    static let window: TimeInterval = 3600
    static let spacing: TimeInterval = 300

    private struct Key: Hashable {
        let pid: pid_t
        let startTime: UInt64
    }

    private struct Checkpoint {
        let date: Date
        /// `mach_absolute_time` when taken, the clock process start times are on.
        let machTime: UInt64
        let totals: [Key: UInt64]
    }

    private struct Seen {
        let total: UInt64
        let responsible: pid_t
    }

    private struct Departure {
        let date: Date
        let responsible: pid_t
        let joules: Double
    }

    private var checkpoints: [Checkpoint] = []
    private var lastSeen: [Key: Seen] = [:]
    private var departures: [Departure] = []

    /// How far back the figures reach: the full hour once the ledger has run that long.
    func span(now: Date = .now) -> TimeInterval? {
        checkpoints.first.map { now.timeIntervalSince($0.date) }
    }

    var isCheckpointDue: Bool {
        guard let last = checkpoints.last else { return true }
        return Date().timeIntervalSince(last.date) >= Self.spacing
    }

    /// Takes in a reading of every process it could read. `alive` is every pid that exists,
    /// readable or not, so a process that merely became unreadable isn't taken for gone.
    mutating func record(_ counters: [pid_t: ProcessCounters], responsible: [pid_t: pid_t], alive: Set<pid_t>) {
        let now = Date()
        var seen: [Key: Seen] = [:]
        seen.reserveCapacity(counters.count)
        for (pid, c) in counters {
            seen[Key(pid: pid, startTime: c.startTime)] = Seen(total: c.energy, responsible: responsible[pid] ?? pid)
        }
        for (key, last) in lastSeen where seen[key] == nil && !alive.contains(key.pid) {
            if let joules = joules(key, total: last.total), joules > 0, last.responsible != key.pid {
                departures.append(Departure(date: now, responsible: last.responsible, joules: joules))
            }
        }
        lastSeen = seen

        if isCheckpointDue {
            checkpoints.append(Checkpoint(date: now, machTime: mach_absolute_time(),
                                          totals: seen.mapValues(\.total)))
        }
        // The oldest checkpoint still inside the hour is the baseline.
        let start = now.addingTimeInterval(-Self.window)
        checkpoints.removeAll { $0.date < start }
        departures.removeAll { $0.date < start }
    }

    /// Joules each process used over the window, plus what its quit helpers used. A process
    /// is left out if it was already running at the baseline but couldn't be read then, so how
    /// much of its total falls in the window is unknown.
    func energies(_ counters: [pid_t: ProcessCounters]) -> [pid_t: Double] {
        let departed = departures.reduce(into: [pid_t: Double]()) { $0[$1.responsible, default: 0] += $1.joules }
        var result: [pid_t: Double] = [:]
        for (pid, c) in counters {
            guard let own = joules(Key(pid: pid, startTime: c.startTime), total: c.energy) else { continue }
            result[pid] = own + (departed[pid] ?? 0)
        }
        return result
    }

    private func joules(_ key: Key, total: UInt64) -> Double? {
        guard let baseline = checkpoints.first else { return nil }
        if let before = baseline.totals[key] {
            return Double(total &- before) / 1e9
        }
        // Started after the baseline: everything it has used falls inside the window.
        return key.startTime > baseline.machTime ? Double(total) / 1e9 : nil
    }
}
