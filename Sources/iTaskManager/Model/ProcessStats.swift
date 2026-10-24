import Foundation

struct ProcessStats: Sendable, Identifiable {
    let id: pid_t
    var name: String
    var path: String?
    var responsiblePID: pid_t
    /// Owner; anything not run by the current user counts as a system process.
    var uid: uid_t?
    /// CPU cycles per second, and the part run on performance cores. nil when the process
    /// belongs to another user and its usage can't be read.
    var cycleRate: Double?
    var pCycleRate: Double?
    /// CPU seconds per second (1 = one core busy), for Macs without clock tables.
    var timeRate: Double?
    var pTimeRate: Double?
    var memory: UInt64?
    var power: Double?
    /// Joules used over the last hour (see `EnergyLedger`), including helpers it was
    /// responsible for that have since quit.
    var energy: Double?
    /// Bytes per second, read + write.
    var disk: Double?
}
