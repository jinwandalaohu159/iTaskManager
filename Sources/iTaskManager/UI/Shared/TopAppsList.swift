import SwiftUI

extension ProcessMetric {
    var color: Color {
        switch self {
        case .cpu: Palette.cpu
        case .memory: Palette.memory
        case .power: Palette.power
        }
    }

    func label(of row: ProcessRow) -> String {
        switch self {
        case .cpu: row.cpu.map { Fmt.cpu($0) + "%" } ?? "—"
        case .memory: row.memory.map(Fmt.bytes) ?? "—"
        case .power: row.power.map(Fmt.watts) ?? "—"
        }
    }
}

/// A short ranked list of the busiest apps. The order comes from the monitor's stable
/// ranking, so rows glide into new places only when the ranking really changes.
struct TopAppsList: View {
    let metric: ProcessMetric
    var limit = 6
    var showsBars = true

    @Environment(SystemMonitor.self) private var monitor
    @Environment(\.smoothMotion) private var smooth

    var body: some View {
        let rows = monitor.processes.top(metric, limit: limit)
        let peak = max(rows.map(metric.value).max() ?? 0, 0.0001)
        VStack(spacing: 2) {
            if rows.isEmpty {
                ForEach(0..<limit, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)).frame(height: 26)
                }
            }
            ForEach(rows) { row in
                HStack(spacing: 12) {
                    ProcessIconView(icon: row.icon, size: 18)
                    if showsBars {
                        Text(row.name).lineLimit(1).truncationMode(.tail)
                            .frame(width: 190, alignment: .leading)
                        UsageBar(value: metric.value(of: row) / peak, color: metric.color, height: 6)
                    } else {
                        Text(row.name).lineLimit(1).truncationMode(.tail)
                        Spacer(minLength: 8)
                    }
                    Text(metric.label(of: row))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 72, alignment: .trailing)
                }
                .font(.callout)
                .padding(.vertical, 4)
                .transition(.opacity)
            }
        }
        .animation(smooth ? .smooth(duration: 0.4) : nil, value: rows.map(\.id))
    }
}
