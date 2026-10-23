import SwiftUI

/// Donut, legend and the other figures side by side; in a narrow window the figures move
/// under the donut in two columns, so nothing has to wrap or overlap.
struct MemorySummary: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        Card(padding: 20) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 36) {
                    donut(size: 176)
                    totals.frame(maxWidth: 340)
                    Divider().frame(height: 150)
                    VStack(alignment: .leading, spacing: 10) {
                        pressure
                        cachedRows
                        otherRows
                    }
                    .frame(maxWidth: .infinity)
                }
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .center, spacing: 28) {
                        donut(size: 150)
                        totals
                    }
                    Divider()
                    pressure
                    HStack(alignment: .top, spacing: 28) {
                        VStack(spacing: 10) { cachedRows }
                        VStack(spacing: 10) { otherRows }
                    }
                }
            }
        }
    }

    private var parts: [MemoryBreakdown.Part] {
        monitor.memory.map { MemoryBreakdown.parts($0, monitor.memoryAttribution) } ?? []
    }

    private func donut(size: CGFloat) -> some View {
        let memory = monitor.memory
        return DonutChart(
            segments: parts.map { Segment(id: $0.id, color: $0.color, value: Double($0.bytes)) },
            total: Double(monitor.chip.memoryBytes),
            lineWidth: 18
        ) {
            GaugeCenter(text: Fmt.percent(memory?.usedFraction ?? 0), value: memory?.usedFraction ?? 0, caption: L("已使用"))
        }
        .frame(width: size, height: size)
    }

    /// Used of total, then who holds it.
    private var totals: some View {
        let memory = monitor.memory
        let total = Fmt.bytes(monitor.chip.memoryBytes)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                LiveNumber(text: Fmt.bytes(memory?.used ?? 0), value: Double(memory?.used ?? 0), size: 30, template: Fmt.bytesTemplate)
                ViewThatFits(in: .horizontal) {
                    Text(L("/ \(total) 统一内存"))
                    Text("/ \(total)")
                }
                .foregroundStyle(.secondary)
            }
            VStack(spacing: 8) {
                ForEach(parts) { part in
                    LegendRow(color: part.color, label: part.label, value: Fmt.bytes(part.bytes), info: part.help)
                }
            }
        }
    }

    @ViewBuilder
    private var pressure: some View {
        if let memory = monitor.memory { PressureBadge(pressure: memory.pressure) }
    }

    @ViewBuilder
    private var cachedRows: some View {
        let memory = monitor.memory
        InfoRow(label: L("已缓存文件"), value: Fmt.bytes(memory?.cached ?? 0),
                info: L("最近读过的文件内容，不算在已使用里，需要时随时释放"))
        InfoRow(label: L("被压缩"), value: Fmt.bytes(memory?.compressed ?? 0),
                info: L("被压缩以节省空间的内存。它已经计入左侧各进程的占用，这里单独列出。"))
    }

    @ViewBuilder
    private var otherRows: some View {
        let memory = monitor.memory
        InfoRow(label: L("交换区"), value: "\(Fmt.bytes(memory?.swapUsed ?? 0)) / \(Fmt.bytes(memory?.swapTotal ?? 0))")
        InfoRow(label: L("GPU 占用", context: "memory"), value: Fmt.bytes(monitor.gpu?.memoryInUse ?? 0))
        InfoRow(label: L("可用"), value: Fmt.bytes((memory?.total ?? 0) &- (memory?.used ?? 0)))
    }
}
