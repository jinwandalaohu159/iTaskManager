import SwiftUI

/// An app icon, or an SF Symbol for processes without one.
struct ProcessIconView: View {
    let icon: ProcessIcon
    var size: CGFloat = 16

    var body: some View {
        switch icon {
        case .image(let image):
            Image(nsImage: image).resizable().interpolation(.high).frame(width: size, height: size)
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: size * 0.75))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
        }
    }
}
