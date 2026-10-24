import Foundation

/// One family of temperature sensors, in °C.
struct SensorGroup: Sendable, Equatable {
    var average: Double
    var maximum: Double
}

/// Each family is nil where this Mac has no such sensors.
struct Temperatures: Sendable, Equatable {
    /// Every CPU sensor, both clusters together.
    var cpu: SensorGroup?
    var performance: SensorGroup?
    var efficiency: SensorGroup?
    var gpu: SensorGroup?
    var battery: SensorGroup?

    func cluster(_ kind: CoreKind) -> SensorGroup? {
        kind == .performance ? performance : efficiency
    }
}
