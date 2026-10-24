import SwiftUI

/// A sensor group's average, with its hottest sensor on hover.
struct TemperatureLabel: View {
    let group: SensorGroup

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "thermometer.medium")
            Text(Fmt.celsius(group.average))
                .monospacedDigit()
                .reservingWidth(of: Fmt.celsiusTemplate, alignment: .leading)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .help(L("该部位 SMC 温度传感器的平均 \(Fmt.celsius(group.average)) · 最高 \(Fmt.celsius(group.maximum))"))
    }
}
