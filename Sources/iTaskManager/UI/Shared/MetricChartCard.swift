import SwiftUI

/// A title, the current reading and its recent curve: the CPU and GPU power cards, the GPU
/// temperature card.
struct MetricChartCard: View {
    let title: String
    let color: Color
    let reading: String
    let value: Double
    let history: History
    let ceiling: Double
    let format: (Double) -> String
    let axisFormat: (Double) -> String
    /// Shown on hover over the reading.
    var readingHelp: String? = nil

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.headline)
                    Spacer()
                    LiveNumber(text: reading, value: value, size: 20)
                        .help(readingHelp ?? "")
                }
                LiveChart(
                    series: [ChartSeries(id: title, color: color, values: history.values)],
                    maxValue: ceiling,
                    style: .full,
                    format: format,
                    axisFormat: axisFormat
                )
                .frame(height: 110)
            }
        }
    }
}
