import SwiftUI

/// The horizontal grid of a full chart. Its lines sit at fixed fractions of the height,
/// whatever the scale, so it only depends on the plot size and is skipped when charts
/// refresh with new data instead of being rasterised again every second.
struct ChartGrid: View, Equatable {
    let size: CGSize
    let inset: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let scale = ChartScale(maxValue: 1, height: size.height, inset: inset)
            for fraction in [0.0, 0.25, 0.5, 0.75, 1.0] {
                let yPos = scale.y(fraction).rounded() + 0.5
                var path = Path()
                path.move(to: CGPoint(x: 0, y: yPos))
                path.addLine(to: CGPoint(x: canvasSize.width, y: yPos))
                context.stroke(path, with: .color(.primary.opacity(fraction == 0 ? 0.14 : 0.07)), lineWidth: 1)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}
