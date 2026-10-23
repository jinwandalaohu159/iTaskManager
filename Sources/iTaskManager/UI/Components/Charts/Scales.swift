import SwiftUI

/// Maps a value to a y position in a plot, inset so a thick line at either end isn't clipped.
/// Shared by the line layers, grid, axis and hover so they always agree.
struct ChartScale {
    let maxValue: Double
    let height: CGFloat
    var inset: CGFloat = 0

    func y(_ value: Double) -> CGFloat {
        let fraction = maxValue > 0 ? min(max(value / maxValue, 0), 1) : 0
        return inset + (height - inset * 2) * (1 - fraction)
    }
}

/// Rounds a chart ceiling up to a stable, readable value so the axis doesn't twitch.
func niceCeiling(_ value: Double, minimum: Double = 5) -> Double {
    let steps: [Double] = [0.5, 1, 2, 5, 10, 15, 20, 30, 40, 60, 80, 100, 150, 200, 300]
    let target = max(value * 1.1, minimum)
    return steps.first { $0 >= target } ?? target
}

/// Ceiling for a 0...1 series: zooms in on light loads while staying on fixed, labelled steps.
func fractionCeiling(_ values: [Double]) -> Double {
    let peak = (values.max() ?? 0) * 1.15
    // Steps whose midpoints (the middle grid line) are whole percentages.
    return [0.1, 0.2, 0.5].first { $0 >= peak } ?? 1
}
