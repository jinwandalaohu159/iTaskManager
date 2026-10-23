import SwiftUI

/// The landing page. It only arranges cards; each card observes just the data it shows.
struct OverviewPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                OverviewHeader().reveal(0)
                EqualColumns(minItemWidth: 190) {
                    CPUTile()
                    MemoryTile()
                    GPUTile()
                    PowerTile()
                }
                .reveal(1)
                CoreMetersCard().reveal(2)
                HStack(alignment: .top, spacing: 16) {
                    MemorySummaryCard()
                    PowerSummaryCard()
                }
                .equalHeightRow()
                .reveal(3)
                TopAppsCard().reveal(4)
            }
            .padding(24)
        }
    }
}

private struct OverviewHeader: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let chip = monitor.chip
        VStack(alignment: .leading, spacing: 4) {
            Text(chip.name)
                .font(.system(size: 26, weight: .bold))
            Text(L("\(chip.hostName) · \(chip.coreKinds.count) 核 CPU（\(chip.performanceCount) 性能核 + \(chip.efficiencyCount) 能效核）· \(chip.gpuCores) 核 GPU · \(Fmt.bytes(chip.memoryBytes)) 统一内存 · macOS \(chip.osVersion)"))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

private struct MemorySummaryCard: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(\.navigate) private var navigate

    var body: some View {
        let memory = monitor.memory
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: L("内存")) {
                    if let memory { PressureBadge(pressure: memory.pressure) }
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    LiveNumber(text: Fmt.bytes(memory?.used ?? 0), value: Double(memory?.used ?? 0), template: Fmt.bytesTemplate)
                    Text("/ \(Fmt.bytes(monitor.chip.memoryBytes))").foregroundStyle(.secondary)
                }
                if let memory {
                    MemoryComposition(memory: memory, attribution: monitor.memoryAttribution)
                }
            }
        }
        .onTapGesture { navigate(.memory) }
    }
}

private struct PowerSummaryCard: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(\.navigate) private var navigate

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: L("能耗")) {
                    if let battery = monitor.battery { BatterySummary(battery: battery) }
                }
                if let power = monitor.power, let total = monitor.systemWatts {
                    VStack(alignment: .leading, spacing: 2) {
                        LiveNumber(text: Fmt.wattsFixed(total), value: total)
                        Text(L("整机功耗")).font(.callout).foregroundStyle(.secondary)
                    }
                    PowerBreakdown(power: power)
                } else {
                    Text(L("此 Mac 不支持功耗读取")).foregroundStyle(.secondary)
                }
            }
        }
        .onTapGesture { navigate(.energy) }
    }
}

private struct TopAppsCard: View {
    @Environment(\.navigate) private var navigate

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: L("占用最高的应用"), subtitle: L("按 CPU 排序")) {
                    Button(L("全部进程")) { navigate(.processes) }
                        .buttonStyle(.link)
                }
                TopAppsList(metric: .cpu, limit: 6)
            }
        }
    }
}
