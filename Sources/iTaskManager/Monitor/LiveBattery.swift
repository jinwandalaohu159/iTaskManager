import Foundation

/// Brings battery readings up to date. The battery gauge publishes once a minute and the
/// charger takes a few seconds to start after plugging in; this fills both gaps from the
/// per-sample power readings, so the battery views react within a second.
struct LiveBattery {
    private var estimator = BatteryEstimator()
    private var wasPluggedIn: Bool?
    private var pluggedInAt: Date?

    /// How long after plugging in a battery that isn't charging yet counts as "about to".
    private static let chargingGrace: TimeInterval = 8

    mutating func adjust(_ reading: BatteryStats, power: PowerStats?, systemWatts: Double?, at date: Date) -> BatteryStats {
        var battery = reading
        // On battery, time left and discharge rate come from the live output power.
        if let minutes = estimator.update(battery: battery, drain: power?.battery ?? systemWatts, at: date) {
            battery.timeRemaining = minutes
        }
        if !battery.isPluggedIn, let live = power?.battery, live > 0 {
            battery.watts = -live
        }
        // Plugged in, the gauge lags by about a minute; what the adapter supplies beyond the
        // Mac's own use is live.
        if battery.isPluggedIn, let input = power?.adapterInput {
            battery.watts = ChargeFlow(input: input, system: min(systemWatts ?? 0, input)).battery
            if battery.watts > 1, !battery.isFullyCharged { battery.isCharging = true }
        }

        if battery.isPluggedIn, wasPluggedIn == false { pluggedInAt = date }
        if !battery.isPluggedIn { pluggedInAt = nil }
        wasPluggedIn = battery.isPluggedIn
        if let pluggedInAt, !battery.isCharging, !battery.isFullyCharged,
           date.timeIntervalSince(pluggedInAt) < Self.chargingGrace {
            battery.chargingStarting = true
        }
        return battery
    }
}
