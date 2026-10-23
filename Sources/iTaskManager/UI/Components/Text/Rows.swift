import SwiftUI

/// A legend entry: swatch, label and value.
struct LegendRow: View {
    let color: Color
    let label: String
    let value: String
    /// An explanation shown from a "?" after the label.
    var info: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).foregroundStyle(.secondary)
            if let info { InfoBadge(text: info) }
            Spacer(minLength: 8)
            Text(value).monospacedDigit()
        }
        .font(.callout)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    /// An explanation shown from a "?" after the label.
    var info: String? = nil

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            if let info { InfoBadge(text: info) }
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.callout)
    }
}

extension View {
    /// Lays the view out at the width of `template` (e.g. "100%"), so a value whose digits
    /// change never pushes its neighbours around. Apply before `.font` so both share it.
    func reservingWidth(of template: String, alignment: Alignment = .leading) -> some View {
        Text(template)
            .monospacedDigit()
            .hidden()
            .overlay(alignment: alignment) { self.fixedSize() }
    }
}

/// Inline "label value" pairs where every value keeps a fixed width. Values are right-aligned
/// in that width, so the spare room sits between label and value and the gaps between pairs
/// stay even.
struct InlineStats: View {
    struct Item: Identifiable {
        let label: String
        let value: String
        /// The widest value expected, e.g. "100%".
        let template: String

        var id: String { label }
    }

    let items: [Item]
    var separator: String? = nil
    var spacing: CGFloat = 16

    /// One line when it fits; otherwise split over two, leading-aligned.
    var body: some View {
        ViewThatFits(in: .horizontal) {
            line(items[...])
            let half = (items.count + 1) / 2
            VStack(alignment: .leading, spacing: 4) {
                line(items[..<half])
                line(items[half...])
            }
        }
    }

    private func line(_ items: ArraySlice<Item>) -> some View {
        HStack(spacing: separator == nil ? spacing : 4) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if let separator, index > 0 {
                    Text(separator).foregroundStyle(.tertiary)
                }
                HStack(spacing: 4) {
                    if !item.label.isEmpty {
                        Text(item.label).foregroundStyle(.secondary)
                    }
                    Text(item.value).monospacedDigit().reservingWidth(of: item.template, alignment: .trailing)
                }
            }
        }
    }
}
