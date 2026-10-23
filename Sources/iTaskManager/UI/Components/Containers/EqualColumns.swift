import SwiftUI

/// Lays items out in equal-width columns. The column count is the largest one that fits
/// `minItemWidth` and divides the item count evenly, so rows are always full: four items
/// become 4 × 1 or 2 × 2, never 3 + 1 or 4 with an empty fifth slot.
struct EqualColumns: Layout {
    var minItemWidth: CGFloat
    var spacing: CGFloat = 16

    private func columns(for width: CGFloat, count: Int) -> Int {
        guard count > 0 else { return 1 }
        let fitting = max(1, Int((width + spacing) / (minItemWidth + spacing)))
        var columns = min(fitting, count)
        while columns > 1 && count % columns != 0 { columns -= 1 }
        return columns
    }

    private func itemWidth(_ width: CGFloat, columns: Int) -> CGFloat {
        (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? minItemWidth * CGFloat(subviews.count)
        let columns = columns(for: width, count: subviews.count)
        let itemWidth = itemWidth(width, columns: columns)
        let rows = stride(from: 0, to: subviews.count, by: columns).map { start in
            subviews[start..<min(start + columns, subviews.count)]
                .map { $0.sizeThatFits(ProposedViewSize(width: itemWidth, height: nil)).height }
                .max() ?? 0
        }
        return CGSize(width: width, height: rows.reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let columns = columns(for: bounds.width, count: subviews.count)
        let itemWidth = itemWidth(bounds.width, columns: columns)
        var y = bounds.minY
        for start in stride(from: 0, to: subviews.count, by: columns) {
            let row = subviews[start..<min(start + columns, subviews.count)]
            // Every item in a row takes the row's height so card bottoms line up.
            let height = row.map { $0.sizeThatFits(ProposedViewSize(width: itemWidth, height: nil)).height }.max() ?? 0
            for (offset, subview) in row.enumerated() {
                let x = bounds.minX + CGFloat(offset) * (itemWidth + spacing)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: itemWidth, height: height))
            }
            y += height + spacing
        }
    }
}
