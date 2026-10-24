import SwiftUI

struct EnergyPage: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(\.smoothMotion) private var smooth

    var body: some View {
        // Depends only on what this Mac supports, so the page itself rarely re-renders.
        let hasPower = monitor.hasPowerReadings
        let charging = monitor.hasChargeFlow
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if hasPower {
                    // The charging card carries the gap above it, so rolling it up closes the gap too.
                    VStack(spacing: 0) {
                        SystemPowerCard()
                        if charging {
                            ChargingCard()
                                .padding(.top, 16)
                                .transition(.asymmetric(insertion: .opacity, removal: .collapseUp))
                        }
                    }
                    .reveal(0)
                    HStack(alignment: .top, spacing: 16) {
                        ComponentPowerCard(title: L("CPU 功耗"), color: Palette.cpu, part: \.cpu, history: \.cpuPowerHistory)
                        ComponentPowerCard(title: L("GPU 功耗"), color: Palette.gpu, part: \.gpu, history: \.gpuPowerHistory)
                    }
                    .equalHeightRow()
                    .reveal(1)
                } else {
                    Card {
                        Label(L("此 Mac 不支持读取功耗数据"), systemImage: "bolt.slash")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(alignment: .top, spacing: 16) { batteryAndApps }
                    .equalHeightRow()
                    .reveal(2)
            }
            .padding(24)
            // Plugging in or out: the charging card fades and the cards below glide.
            .animation(smooth ? .smooth(duration: 0.35) : nil, value: charging)
        }
    }

    @ViewBuilder
    private var batteryAndApps: some View {
        if monitor.hasBattery {
            BatteryCard()
        }
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: L("耗电最多的应用"), subtitle: energyPeriod)
                TopAppsList(metric: .energy, limit: 8)
            }
        }
    }

    /// The figures cover the last hour once the app has been running that long.
    private var energyPeriod: String {
        guard let minutes = monitor.energyMinutes, minutes < 55 else { return L("过去 1 小时") }
        return L("过去 \(max(minutes, 1)) 分钟")
    }
}

private struct SystemPowerCard: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        if let power = monitor.power {
            let parts = PowerBreakdown.parts(of: power)
            let total = monitor.systemWatts ?? 0
            GaugeChartCard(title: L("整机功耗"), chartHeight: 300) {
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
