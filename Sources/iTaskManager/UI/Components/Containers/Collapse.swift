import SwiftUI

extension AnyTransition {
    /// Rolls a view up as it leaves: its height shrinks to nothing from the bottom edge, so what
    /// follows slides up in step and nothing overlaps.
    static var collapseUp: AnyTransition {
        .modifier(active: CollapseModifier(fraction: 0), identity: CollapseModifier(fraction: 1))
    }
}

private struct CollapseModifier: ViewModifier {
    let fraction: Double

    func body(content: Content) -> some View {
        CollapseLayout(fraction: fraction) { content }
            .clipped()
            .opacity(fraction)
    }
}

/// Takes `fraction` of its content's height and lays the content out at full height from the
/// top, leaving the rest to be clipped.
private struct CollapseLayout: Layout {
    var fraction: Double

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let content = subviews.first else { return .zero }
        let size = content.sizeThatFits(proposal)
        return CGSize(width: size.width, height: size.height * fraction)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let content = subviews.first else { return }
        let size = content.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
        content.place(at: bounds.origin, anchor: .topLeading,
                      proposal: ProposedViewSize(width: bounds.width, height: size.height))
    }
}
