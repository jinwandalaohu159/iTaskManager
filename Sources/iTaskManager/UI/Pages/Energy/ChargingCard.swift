import SwiftUI

/// While plugged in: the adapter's power, how it splits between the Mac and the battery, and
/// the recent curve of both parts.
struct ChargingCard: View {
    @Environment(SystemMonitor.self) private var monitor
    /// The last reading while plugged in. Unplugged, the readings go at once, but the card is
    /// still fading out; it keeps showing these rather than collapsing as it goes.
    @State private var held: (flow: ChargeFlow, battery: BatteryStats)?

    var body: some View {
        let current = monitor.chargeFlow.flatMap { flow in monitor.battery.map { (flow: flow, battery: $0) } }
        Group {
            if let shown = current ?? held {
                card(shown.flow, shown.battery)
            }
        }
        .onChange(of: monitor.chargeFlow, initial: true) {
            if let current { held = current }
        }
    }

    private func card(_ flow: ChargeFlow, _ battery: BatteryStats) -> some View {
        GaugeChartCard(title: L("充电")) {
            DonutChart(
                segments: [
                    Segment(id: "system", color: Palette.power, value: flow.system),
                    Segment(id: "battery", color: Palette.good, value: flow.battery),
                ],
                total: max(flow.input, 0.001),
                lineWidth: 18
            ) {
                GaugeCenter(text: String(format: "%.1f", flow.input), value: flow.input, caption: L("输入 W"))
            }
        } legend: {
            LegendRow(color: Palette.power, label: L("供给系统"), value: Fmt.wattsFixed(flow.system))
            LegendRow(color: Palette.good, label: L("充入电池"), value: Fmt.wattsFixed(flow.battery))
        } facts: {
            InlineStats(items: facts(battery))
                .font(.callout)
        } chart: {
            LiveChart(
                series: [
                    ChartSeries(id: "system", color: Palette.power, values: monitor.chargeSystemHistory.values),
                    ChartSeries(id: "battery", color: Palette.good, values: monitor.chargeBatteryHistory.values),
                ],
                maxValue: niceCeiling(max(monitor.chargeSystemHistory.max, monitor.chargeBatteryHistory.max)),
                style: .full,
                format: Fmt.watts,
                axisFormat: Fmt.axisWatts
            )
        }
    }

    private func facts(_ battery: BatteryStats) -> [InlineStats.Item] {
        var items: [InlineStats.Item] = [.init(label: L("状态"), value: battery.stateLabel, template: L("已接通电源"))]
        if let adapter = battery.adapterWatts {
            items.append(.init(label: L("电源适配器"), value: "\(adapter) W", template: "000 W"))
        }
        if battery.isCharging, let minutes = battery.timeRemaining {
            items.append(.init(label: L("充满还需"), value: Fmt.minutes(minutes), template: Fmt.minutesTemplate))
        }
        return items
    }
}
