import SwiftUI

/// Charge, state and the battery's own figures.
struct BatteryCard: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(\.smoothMotion) private var smooth

    var body: some View {
        if let battery = monitor.battery {
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: L("电池"))
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
                        label: battery.watts >= 0 ? L("充电功率") : L("放电功率"),
                        value: Fmt.wattsFixed(abs(battery.watts))
                    )
                    if let adapter = battery.adapterWatts, battery.isPluggedIn {
                        InfoRow(label: L("电源适配器"), value: "\(adapter) W")
                            .transition(.opacity)
                    }
                    if let minutes = battery.timeRemaining {
                        InfoRow(label: battery.isCharging ? L("充满还需") : L("剩余使用时间"), value: Fmt.minutes(minutes))
                            .transition(.opacity)
                    }
                    if let health = battery.health {
                        InfoRow(label: L("最大容量"), value: Fmt.percent(min(health, 1)))
                    }
                    if let cycles = battery.cycleCount {
                        InfoRow(label: L("循环次数"), value: "\(cycles)")
                    }
                    if let temperature = battery.temperature {
                        InfoRow(label: L("温度"), value: Fmt.celsius(temperature))
                    }
                }
                // Rows that come and go with plugging in or out fade instead of popping.
                .animation(smooth ? .smooth(duration: 0.35) : nil, value: battery.isPluggedIn)
                .animation(smooth ? .smooth(duration: 0.35) : nil, value: battery.timeRemaining == nil)
            }
            .frame(maxWidth: 360)
        }
    }
}
