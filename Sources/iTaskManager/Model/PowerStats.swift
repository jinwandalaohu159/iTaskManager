import Foundation

/// Watts.
struct PowerStats: Sendable {
    var cpu: Double
    var ecpu: Double
    var pcpu: Double
    var gpu: Double
    var ane: Double
    /// Live where the chip's memory record is known; elsewhere nil until the batched Energy
    /// Model counter has produced a reading (see `BatchedRate`).
    var dram: Double?
    var hasClusterSplit: Bool
    /// Whole-system power from the SMC, when available.
    var system: Double?
    /// What the battery is putting out right now (SMC), conversion losses included, so a little
    /// more than `system` while on battery.
    var battery: Double? = nil
    /// Power coming in from the adapter (SMC), when one is connected and supplying.
    var adapterInput: Double? = nil
}

/// Where the adapter's power goes while plugged in, in watts.
struct ChargeFlow: Equatable {
    /// From the adapter.
    var input: Double
    /// To the Mac itself.
    var system: Double

    /// The rest goes into the battery. Measured on an M5 charging from a 68 W adapter this
    /// matched the battery gauge's voltage × current (57.8 W both), and unlike the gauge,
    /// which lags by about a minute, it's live. 0 once the battery is full or charging pauses.
    var battery: Double { max(input - system, 0) }
}
