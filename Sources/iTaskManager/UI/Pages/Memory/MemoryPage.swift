import SwiftUI

struct MemoryPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                MemorySummary().reveal(0)
                MemoryHistoryCard().reveal(1)
                Card(padding: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: L("占用内存最多的应用"), subtitle: L("包含各自的辅助进程"))
                        TopAppsList(metric: .memory, limit: 8)
                    }
                }
                .reveal(2)
            }
            .padding(24)
        }
    }
}

private struct MemoryHistoryCard: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        Card(padding: 20) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: L("最近 60 秒"))
                LiveChart(
                    series: [ChartSeries(id: "mem", color: Palette.memory, values: monitor.memoryHistory.values)],
                    style: .full
                )
                .frame(height: 120)
            }
        }
    }
}
