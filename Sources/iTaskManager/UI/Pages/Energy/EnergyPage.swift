import SwiftUI

struct EnergyPage: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        // Depends only on what this Mac supports, so the page itself rarely re-renders.
        let hasPower = monitor.hasPowerReadings
        let hasBattery = monitor.hasBattery
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if hasPower {
                    SystemPowerCard().reveal(0)
                    HStack(alignment: .top, spacing: 16) {
                        ComponentPowerCard(title: "CPU 功耗", color: Palette.cpu, part: \.cpu, history: \.cpuPowerHistory)
                        ComponentPowerCard(title: "GPU 功耗", color: Palette.gpu, part: \.gpu, history: \.gpuPowerHistory)
                    }
                    .equalHeightRow()
                    .reveal(1)
                } else {
                    Card {
                        Label("此 Mac 不支持读取功耗数据", systemImage: "bolt.slash")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    if hasBattery {
                        BatteryCard()
                    }
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "耗电最多的应用")
                            TopAppsList(metric: .power, limit: 8)
                        }
                    }
                }
                .equalHeightRow()
                .reveal(2)
            }
            .padding(24)
        }
    }
}

private struct SystemPowerCard: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        if let power = monitor.power {
            let parts = PowerBreakdown.parts(of: power)
            let total = monitor.systemWatts ?? 0
            GaugeChartCard(title: "整机功耗", chartHeight: 300) {
                DonutChart(
                    segments: parts.map { Segment(id: $0.id, color: $0.color, value: $0.watts) },
                    total: max(total, 0.001),
                    lineWidth: 18
                ) {
                    GaugeCenter(text: String(format: "%.1f", total), value: total, caption: "W")
                }
            } legend: {
                PowerBreakdown(power: power, showsBar: false)
            } facts: {
                if let battery = monitor.battery {
                    BatterySummary(battery: battery).foregroundStyle(.secondary)
                }
            } chart: {
                LiveChart(
                    series: [ChartSeries(id: "sys", color: Palette.power, values: monitor.systemPowerHistory.values)],
                    maxValue: niceCeiling(monitor.systemPowerHistory.max),
                    style: .full,
                    format: Fmt.watts,
                    axisFormat: Fmt.axisWatts
                )
            }
        }
    }
}

private struct ComponentPowerCard: View {
    let title: String
    let color: Color
    let part: KeyPath<PowerStats, Double>
    let history: KeyPath<SystemMonitor, History>

    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let watts = monitor.power?[keyPath: part] ?? 0
        let values = monitor[keyPath: history]
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.headline)
                    Spacer()
                    LiveNumber(text: Fmt.watts(watts), value: watts, size: 20)
                }
                LiveChart(
                    series: [ChartSeries(id: title, color: color, values: values.values)],
                    maxValue: niceCeiling(values.max, minimum: 0.5),
                    style: .full,
                    format: Fmt.watts,
                    axisFormat: Fmt.axisWatts
                )
                .frame(height: 110)
            }
        }
    }
}

private struct BatteryCard: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        if let battery = monitor.battery {
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "电池")
                    VStack(alignment: .leading, spacing: 2) {
                        LiveNumber(text: Fmt.percent(battery.percent), value: battery.percent, size: 34)
                        BatterySummary(battery: battery, showsPercent: false).foregroundStyle(.secondary)
                    }
                    UsageBar(
                        value: battery.percent,
                        color: battery.percent < 0.2 && !battery.isPluggedIn ? Palette.critical : Palette.good,
                        height: 8
                    )
                    .padding(.bottom, 4)
                    InfoRow(
                        label: battery.watts >= 0 ? "充电功率" : "放电功率",
                        value: Fmt.wattsFixed(abs(battery.watts))
                    )
                    if let adapter = battery.adapterWatts, battery.isPluggedIn {
                        InfoRow(label: "电源适配器", value: "\(adapter) W")
                    }
                    if let minutes = battery.timeRemaining {
                        InfoRow(label: battery.isCharging ? "充满还需" : "剩余使用时间", value: Fmt.minutes(minutes))
                    }
                    if let health = battery.health {
                        InfoRow(label: "最大容量", value: Fmt.percent(min(health, 1)))
                    }
                    if let cycles = battery.cycleCount {
                        InfoRow(label: "循环次数", value: "\(cycles)")
                    }
                    if let temperature = battery.temperature {
                        InfoRow(label: "温度", value: String(format: "%.1f °C", temperature))
                    }
                }
            }
            .frame(maxWidth: 360)
        }
    }
}
