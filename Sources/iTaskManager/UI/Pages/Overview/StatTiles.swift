import SwiftUI

/// A headline figure with a sparkline; clicking opens the matching detail page.
struct StatTile: View {
    let title: String
    let symbol: String
    let value: String
    let numeric: Double
    let detail: [InlineStats.Item]
    let series: ChartSeries
    var maxValue: Double = 1
    let destination: Page

    @Environment(\.navigate) private var navigate

    var body: some View {
        Card(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label(title, systemImage: symbol)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                LiveNumber(text: value, value: numeric)
                InlineStats(items: detail, spacing: 12)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                LiveChart(series: [series], maxValue: maxValue)
                    .frame(height: 46)
                    .padding(.top, 4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { navigate(destination) }
    }
}

struct CPUTile: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let cpu = monitor.cpu
        StatTile(
            title: "CPU", symbol: "cpu",
            value: Fmt.percent(cpu?.total ?? 0), numeric: cpu?.total ?? 0,
            detail: [
                .init(label: "用户", value: Fmt.percent(cpu?.user ?? 0), template: Fmt.percentPartTemplate),
                .init(label: "系统", value: Fmt.percent(cpu?.system ?? 0), template: Fmt.percentPartTemplate),
            ],
            series: ChartSeries(id: "cpu", color: Palette.cpu, values: monitor.cpuHistory.values),
            destination: .processor
        )
    }
}

struct MemoryTile: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let memory = monitor.memory
        StatTile(
            title: "内存", symbol: "memorychip",
            value: Fmt.percent(memory?.usedFraction ?? 0), numeric: memory?.usedFraction ?? 0,
            detail: [
                .init(label: "已用", value: Fmt.bytes(memory?.used ?? 0), template: Fmt.bytesTemplate),
                .init(label: "共", value: Fmt.bytes(monitor.chip.memoryBytes), template: Fmt.bytesTemplate),
            ],
            series: ChartSeries(id: "mem", color: Palette.memory, values: monitor.memoryHistory.values),
            destination: .memory
        )
    }
}

struct GPUTile: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let gpu = monitor.gpu
        StatTile(
            title: "GPU", symbol: "square.stack.3d.up",
            value: Fmt.percent(gpu?.utilization ?? 0), numeric: gpu?.utilization ?? 0,
            detail: [
                .init(label: "核心", value: "\(monitor.chip.gpuCores)", template: "00"),
                .init(label: "显存", value: Fmt.bytes(gpu?.memoryInUse ?? 0), template: Fmt.bytesTemplate),
            ],
            series: ChartSeries(id: "gpu", color: Palette.gpu, values: monitor.gpuHistory.values),
            destination: .processor
        )
    }
}

struct PowerTile: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let watts = monitor.systemWatts ?? 0
        StatTile(
            title: "功耗", symbol: "bolt",
            value: Fmt.wattsFixed(watts), numeric: watts,
            detail: [
                .init(label: "CPU", value: monitor.power.map { Fmt.watts($0.cpu) } ?? "—", template: Fmt.wattsTemplate),
                .init(label: "GPU", value: monitor.power.map { Fmt.watts($0.gpu) } ?? "—", template: Fmt.wattsTemplate),
            ],
            series: ChartSeries(id: "power", color: Palette.power, values: monitor.systemPowerHistory.values),
            maxValue: niceCeiling(monitor.systemPowerHistory.max),
            destination: .energy
        )
    }
}
