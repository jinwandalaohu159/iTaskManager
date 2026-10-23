import SwiftUI

/// "内存压力 正常/偏高/紧张" as a tinted capsule.
struct PressureBadge: View {
    let pressure: MemoryPressure

    var body: some View {
        let (label, symbol, color): (String, String, Color) = switch pressure {
        case .normal: ("正常", "checkmark.circle.fill", Palette.good)
        case .warning: ("偏高", "exclamationmark.triangle.fill", Palette.warning)
        case .critical: ("紧张", "xmark.octagon.fill", Palette.critical)
        }
        Label {
            Text("内存压力 \(label)")
        } icon: {
            Image(systemName: symbol).foregroundStyle(color)
        }
        .font(.callout.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.14)))
        .contentTransition(.symbolEffect(.replace))
    }
}
