import Foundation

/// One reading of everything, taken together off the main thread.
struct Snapshot: Sendable {
    var date: Date
    var cpu: CPUStats
    var memory: MemoryStats
    var gpu: GPUStats?
    var power: PowerStats?
    var battery: BatteryStats?
    /// nil while nothing shows them, so they weren't read.
    var temperatures: Temperatures?
    var processes: [ProcessStats]?
    /// How far back the processes' `energy` reaches, up to an hour.
    var processEnergySpan: TimeInterval?
}
