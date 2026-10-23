import Foundation

/// CPU use as a share of full-clock capacity: a core that's busy half the time at a third of
/// its top clock is at 1/6. Busy time alone overstates light loads, when cores run slowly.
struct CPUStats: Sendable {
    /// 0...1 per logical core.
    var perCore: [Double]
    /// Cycles used / cycles available with every core at its top clock.
    var total: Double
    /// `total` split by the share of busy time spent in user and kernel code.
    var user: Double
    var system: Double
    /// Average clock (MHz) of each core kind while running, weighted by busy time; empty where
    /// clocks can't be read, and missing for a kind that was idle throughout.
    var frequency: [CoreKind: Double] = [:]
}

enum MemoryPressure: Sendable {
    case normal, warning, critical
}

struct MemoryStats: Sendable {
    var total: UInt64
    var app: UInt64
    var wired: UInt64
    var compressed: UInt64
    var cached: UInt64
    var swapUsed: UInt64
    var swapTotal: UInt64
    var pressure: MemoryPressure

    /// Same definition as Activity Monitor's "Memory Used".
    var used: UInt64 { app + wired + compressed }
    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

struct GPUStats: Sendable {
    /// Share of the GPU's full-clock capacity in use, 0...1.
    var utilization: Double
    var memoryInUse: UInt64
    /// Average clock (MHz) while busy.
    var frequency: Double? = nil
}

/// Watts.
struct PowerStats: Sendable {
    var cpu: Double
    var ecpu: Double
    var pcpu: Double
    var gpu: Double
    var ane: Double
    var dram: Double
    var hasClusterSplit: Bool
    /// Whole-system power from the SMC, when available.
    var system: Double?
    /// What the battery is putting out right now (SMC), conversion losses included, so a little
    /// more than `system` while on battery.
    var battery: Double? = nil
}

struct BatteryStats: Sendable {
    var percent: Double
    var isCharging: Bool
    var isPluggedIn: Bool
    var isFullyCharged: Bool
    /// Positive while charging, negative while discharging. On battery, `SystemMonitor`
    /// replaces the gauge's once-a-minute reading with the live output power.
    var watts: Double
    /// Minutes to empty or to full; nil while macOS is still estimating. While discharging,
    /// `SystemMonitor` replaces the gauge's figure, which only updates once a minute, with a
    /// live estimate (see `BatteryEstimator`).
    var timeRemaining: Int?
    /// Energy left in the battery, for the live estimate.
    var remainingWattHours: Double?
    /// Just plugged in, and the charger hasn't started yet; it takes the system a few seconds.
    /// Set by `SystemMonitor` so the icon goes straight to charging instead of flickering
    /// through "on power, not charging".
    var chargingStarting = false
    var adapterWatts: Int?
    var cycleCount: Int?
    var health: Double?
    var temperature: Double?
}

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
    /// Bytes per second, read + write.
    var disk: Double?
}

struct Snapshot: Sendable {
    var date: Date
    var cpu: CPUStats
    var memory: MemoryStats
    var gpu: GPUStats?
    var power: PowerStats?
    var battery: BatteryStats?
    var processes: [ProcessStats]?
    /// The processes were read through the root helper, so system ones are included. A few
    /// may still lack figures: ones that started or ended between the helper's read and ours.
    var processesPrivileged = false
}
