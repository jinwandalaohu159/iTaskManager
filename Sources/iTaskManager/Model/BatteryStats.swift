import Foundation

struct BatteryStats: Sendable {
    var percent: Double
    var isCharging: Bool
    var isPluggedIn: Bool
    var isFullyCharged: Bool
    /// Positive while charging, negative while discharging. The gauge's figure lags by about
    /// a minute; `LiveBattery` replaces it with the live battery output, or with what goes into
    /// the battery while plugged in.
    var watts: Double
    /// Minutes to empty or to full; nil while macOS is still estimating. While discharging,
    /// `LiveBattery` replaces the gauge's figure, which only updates once a minute, with a
    /// live estimate (see `BatteryEstimator`).
    var timeRemaining: Int?
    /// Energy left in the battery, for the live estimate.
    var remainingWattHours: Double?
    /// Just plugged in, and the charger hasn't started yet; it takes the system a few seconds.
    /// Set by `LiveBattery` so the icon goes straight to charging instead of flickering
    /// through "on power, not charging".
    var chargingStarting = false
    var adapterWatts: Int?
    var cycleCount: Int?
    var health: Double?
    var temperature: Double?
}
