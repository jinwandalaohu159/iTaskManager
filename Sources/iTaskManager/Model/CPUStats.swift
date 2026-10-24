import Foundation

/// CPU load against every core flat out: a core busy half the time while asked for a third of
/// its top clock is at 1/6, and every core busy at the clock asked of a full load is 100%.
/// Busy time alone overstates light loads, when cores run slowly.
struct CPUStats: Sendable {
    /// 0...1 per logical core.
    var perCore: [Double]
    /// Load against every core flat out (see `ITMCoreActivity.utilization`).
    var total: Double
    /// `total` split by the share of busy time spent in user and kernel code.
    var user: Double
    var system: Double
    /// Average clock (MHz) of each core kind while running, weighted by busy time; empty where
    /// clocks can't be read, and missing for a kind that was idle throughout.
    var frequency: [CoreKind: Double] = [:]
    /// Clock asked of each core kind over the clock it actually ran at. A process's cycles,
    /// counted at the actual clock, times this, are on the same scale as `total`.
    var clockScale: [CoreKind: Double] = [:]
}
