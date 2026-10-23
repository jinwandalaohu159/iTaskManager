import SwiftUI

/// Right-aligns digits inside a fixed box, and the box sits centred in its column,
/// so values line up under a centred header.
struct MetricCell: View {
    let text: String?
    let width: CGFloat
    var secondary = false

    var body: some View {
        Text(text ?? "—")
            .monospacedDigit()
            .foregroundStyle(text == nil ? .tertiary : secondary ? .secondary : .primary)
            .frame(width: width, alignment: .trailing)
            .frame(maxWidth: .infinity)
    }
}

/// Where a process ran: a P/E split bar and the dominant cluster's share.
struct CoreShareCell: View {
    let pShare: Double?

    var body: some View {
        HStack(spacing: 8) {
            if let pShare {
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        if pShare > 0.01 {
                            Rectangle().fill(Palette.pCore).frame(width: max(geo.size.width * pShare - 0.5, 1))
                        }
                        if pShare < 0.99 {
                            Rectangle().fill(Palette.eCore)
                        }
                    }
                    .clipShape(Capsule())
                }
                .frame(width: 34, height: 6)
                HStack(spacing: 0) {
                    Text(pShare >= 0.5 ? "P" : "E")
                        .frame(width: 12, alignment: .leading)
                    Text(Fmt.percent(pShare >= 0.5 ? pShare : 1 - pShare))
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
            } else {
                Color.clear.frame(width: 34, height: 6)
                Text("—").foregroundStyle(.tertiary).frame(width: 52, alignment: .trailing)
            }
        }
        .frame(width: 94)
        .frame(maxWidth: .infinity)
        .help(pShare.map { "性能核 \(Fmt.percent($0)) · 能效核 \(Fmt.percent(1 - $0))" } ?? "最近没有占用 CPU")
    }
}
