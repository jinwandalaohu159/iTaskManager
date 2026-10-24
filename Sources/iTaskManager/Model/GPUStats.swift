import Foundation

struct GPUStats: Sendable {
    /// Share of the GPU's full-clock capacity in use, 0...1.
    var utilization: Double
    var memoryInUse: UInt64
    /// Average clock (MHz) while busy.
    var frequency: Double? = nil
    /// The driver's busy-time shares, 0...1, for the fragment (renderer) and geometry
    /// (tiler) stages. Busy time at any clock, so higher than `utilization` at low clocks.
    var renderer: Double? = nil
    var tiler: Double? = nil
}
