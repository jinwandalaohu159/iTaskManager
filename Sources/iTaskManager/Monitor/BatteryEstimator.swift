import Foundation

/// Time left on battery from live power use. The battery gauge only publishes its own
/// estimate once a minute; battery output power is read every sample, so this follows a real
/// change in load within seconds.
///
/// Three rules keep the figure calm: power is averaged over about 45 seconds; the shown minutes
/// only move once the estimate drifts more than 3% (at least a minute) away from them; and they
/// move at most every 5 seconds. Under a steady load the number holds still; after a real change
/// it steps towards the new value.
struct BatteryEstimator {
    var timeConstant: TimeInterval = 45
    var threshold = 0.03
    var minimumHold: TimeInterval = 5

    private var smoothedWatts: Double?
    private var lastDate: Date?
    private var shown: Int?
    private var shownSince = Date.distantPast

    /// Feeds one sample; returns minutes to empty, or nil when not discharging.
    /// `drain` is the battery's output power, or whole-system power where that isn't readable.
    mutating func update(battery: BatteryStats, drain: Double?, at date: Date) -> Int? {
        guard !battery.isPluggedIn, let watts = drain, watts > 0.5,
              let energy = battery.remainingWattHours, energy > 0
        else {
            reset()
            return nil
        }
        let smoothed: Double
        if let previous = smoothedWatts, let last = lastDate {
            let weight = 1 - exp(-max(date.timeIntervalSince(last), 0) / timeConstant)
            smoothed = previous + (watts - previous) * weight
        } else {
            smoothed = watts
        }
        smoothedWatts = smoothed
        lastDate = date

        let estimate = Int((energy / smoothed * 60).rounded())
        if let current = shown,
           abs(estimate - current) < max(1, Int(Double(current) * threshold))
            || date.timeIntervalSince(shownSince) < minimumHold {
            return current
        }
        shown = estimate
        shownSince = date
        return estimate
    }

    mutating func reset() {
        smoothedWatts = nil
        lastDate = nil
        shown = nil
    }
}
