import SwiftUI

/// One component's power and its recent curve.
struct ComponentPowerCard: View {
    let title: String
    let color: Color
    let part: KeyPath<PowerStats, Double>
    let history: KeyPath<SystemMonitor, History>

    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let watts = monitor.power?[keyPath: part] ?? 0
        let values = monitor[keyPath: history]
        MetricChartCard(
            title: title, color: color, reading: Fmt.watts(watts), value: watts, history: values,
            ceiling: niceCeiling(values.max, minimum: 0.5), format: Fmt.watts, axisFormat: Fmt.axisWatts
        )
    }
}
