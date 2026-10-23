import SwiftUI

/// One core: label, a full-width history and the current value.
struct CoreRow: View {
    let label: String
    let color: Color
    let value: Double
    let history: [Double]
    var ceiling: Double = 1

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .leading)
            LiveChart(series: [ChartSeries(id: label, color: color, values: history)], maxValue: ceiling)
                .padding(.vertical, 6)
            Text(Fmt.percent(value))
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .frame(width: 42, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.035)))
    }
}
