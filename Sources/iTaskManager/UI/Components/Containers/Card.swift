import SwiftUI

/// The content surface used throughout the app: a quiet rounded panel that
/// brightens slightly under the pointer.
struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    @State private var hovering = false

    var body: some View {
        content
            .padding(padding)
            // Expands to the row height when placed side by side with .equalHeightRow().
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(hovering ? 0.06 : 0.04))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
            }
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.18), value: hovering)
    }
}

struct SectionHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.headline)
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            trailing
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// Fades and lifts content in when a page appears, staggered by index.
struct Reveal: ViewModifier {
    let index: Int
    @State private var shown = false
    @Environment(\.smoothMotion) private var smooth

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 12)
            .onAppear {
                guard smooth else { return shown = true }
                withAnimation(.smooth(duration: 0.55).delay(Double(index) * 0.045)) { shown = true }
            }
    }
}

extension View {
    func reveal(_ index: Int) -> some View { modifier(Reveal(index: index)) }

    /// Makes cards in an HStack share the tallest card's height so their bottoms line up.
    func equalHeightRow() -> some View { fixedSize(horizontal: false, vertical: true) }
}
