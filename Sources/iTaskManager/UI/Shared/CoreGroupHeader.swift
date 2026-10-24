import SwiftUI

/// "● 性能核 × 4", optionally followed by the cluster's average load and temperature.
struct CoreGroupHeader: View {
    let kind: CoreKind
    let count: Int
    var average: Double? = nil
    var temperature: SensorGroup? = nil

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(Palette.core(kind)).frame(width: 8, height: 8)
            Text("\(kind.title) × \(count)").font(.callout.weight(.medium))
            if let average {
                Text(Fmt.percent(average))
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .reservingWidth(of: Fmt.percentTemplate, alignment: .leading)
            }
            if let temperature {
                TemperatureLabel(group: temperature)
            }
        }
    }
}
