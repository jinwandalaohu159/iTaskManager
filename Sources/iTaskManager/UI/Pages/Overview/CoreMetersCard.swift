import SwiftUI

/// One vertical meter per core, performance cores first, each with an equal column.
struct CoreMetersCard: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(\.navigate) private var navigate

    var body: some View {
        let chip = monitor.chip
        let usage = monitor.cpu?.perCore ?? Array(repeating: 0, count: chip.coreKinds.count)
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "CPU 核心", subtitle: "\(chip.coreKinds.count) 核") {
                    Button("详情") { navigate(.processor) }
                        .buttonStyle(.link)
                }
                // Every core gets an equal column, so the two groups fill the row in proportion.
                GeometryReader { geo in
                    let gap: CGFloat = 32
                    let column = (geo.size.width - gap) / CGFloat(max(chip.coreKinds.count, 1))
                    HStack(alignment: .top, spacing: gap) {
                        group(.performance, usage: usage, column: column)
                        group(.efficiency, usage: usage, column: column)
                    }
                }
                .frame(height: 150)
            }
        }
    }

    private func group(_ kind: CoreKind, usage: [Double], column: CGFloat) -> some View {
        let indices = monitor.chip.indices(of: kind)
        return VStack(alignment: .leading, spacing: 10) {
            CoreGroupHeader(kind: kind, count: indices.count, average: monitor.chip.average(kind, in: usage))
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(indices.enumerated()), id: \.element) { offset, index in
                    let value = usage[safe: index] ?? 0
                    VStack(spacing: 6) {
                        Text(Fmt.percent(value))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        CoreMeter(value: value, color: Palette.core(kind), width: min(max(column * 0.22, 10), 16))
                            .frame(height: 84)
                        Text("\(kind.prefix)\(offset + 1)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: column)
                }
            }
        }
    }
}
