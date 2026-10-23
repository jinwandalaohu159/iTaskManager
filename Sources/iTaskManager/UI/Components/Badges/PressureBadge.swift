import SwiftUI

/// "内存压力 正常/偏高/紧张" as a tinted capsule.
struct PressureBadge: View {
    let pressure: MemoryPressure

    var body: some View {
        let (label, symbol, color): (String, String, Color) = switch pressure {
        case .normal: (L("正常"), "checkmark.circle.fill", Palette.good)
        case .warning: (L("偏高"), "exclamationmark.triangle.fill", Palette.warning)
        case .critical: (L("紧张"), "xmark.octagon.fill", Palette.critical)
        }
        Label {
            Text(L("内存压力 \(label)"))
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
