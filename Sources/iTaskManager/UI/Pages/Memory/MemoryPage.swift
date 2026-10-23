import SwiftUI

struct MemoryPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                MemorySummary().reveal(0)
                MemoryHistoryCard().reveal(1)
                Card(padding: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "占用内存最多的应用", subtitle: "包含各自的辅助进程")
                        TopAppsList(metric: .memory, limit: 8)
                    }
                }
                .reveal(2)
            }
            .padding(24)
        }
    }
}

private struct MemorySummary: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let memory = monitor.memory
        let parts = memory.map { MemoryBreakdown.parts($0, monitor.memoryAttribution) } ?? []
        Card(padding: 20) {
            HStack(alignment: .center, spacing: 36) {
                DonutChart(
                    segments: parts.map { Segment(id: $0.id, color: $0.color, value: Double($0.bytes)) },
                    total: Double(monitor.chip.memoryBytes),
                    lineWidth: 18
                ) {
                    GaugeCenter(text: Fmt.percent(memory?.usedFraction ?? 0), value: memory?.usedFraction ?? 0, caption: "已使用")
                }
                .frame(width: 176, height: 176)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        LiveNumber(text: Fmt.bytes(memory?.used ?? 0), value: Double(memory?.used ?? 0), size: 30, template: Fmt.bytesTemplate)
                        Text("/ \(Fmt.bytes(monitor.chip.memoryBytes)) 统一内存").foregroundStyle(.secondary)
                    }
                    VStack(spacing: 8) {
                        ForEach(parts) { part in
                            LegendRow(color: part.color, label: part.label, value: Fmt.bytes(part.bytes), info: part.help)
                        }
                    }
                }
                .frame(maxWidth: 340)

                Divider().frame(height: 150)

                VStack(alignment: .leading, spacing: 10) {
                    if let memory { PressureBadge(pressure: memory.pressure) }
                    InfoRow(label: "已缓存文件", value: Fmt.bytes(memory?.cached ?? 0),
                            info: "最近读过的文件内容，不算在已使用里，需要时随时释放")
                    InfoRow(label: "被压缩", value: Fmt.bytes(memory?.compressed ?? 0),
                            info: "被压缩以节省空间的内存。它已经计入左侧各进程的占用，这里单独列出。")
                    InfoRow(label: "交换区", value: "\(Fmt.bytes(memory?.swapUsed ?? 0)) / \(Fmt.bytes(memory?.swapTotal ?? 0))")
                    InfoRow(label: "GPU 占用", value: Fmt.bytes(monitor.gpu?.memoryInUse ?? 0))
                    InfoRow(label: "可用", value: Fmt.bytes((memory?.total ?? 0) &- (memory?.used ?? 0)))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct MemoryHistoryCard: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        Card(padding: 20) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "最近 60 秒")
                LiveChart(
                    series: [ChartSeries(id: "mem", color: Palette.memory, values: monitor.memoryHistory.values)],
                    style: .full
                )
                .frame(height: 120)
            }
        }
    }
}
