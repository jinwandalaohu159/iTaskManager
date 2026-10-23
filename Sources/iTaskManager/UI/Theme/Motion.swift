import SwiftUI

// Written out by hand: the @Entry macro needs a full Xcode toolchain.

private struct SmoothMotionKey: EnvironmentKey {
    static let defaultValue = true
}

private struct NavigateKey: EnvironmentKey {
    static let defaultValue: @MainActor (Page) -> Void = { _ in }
}

extension EnvironmentValues {
    /// Mirrors the "流畅动画" setting: charts glide, numbers roll and meters ease. When off,
    /// every value simply updates in place.
    var smoothMotion: Bool {
        get { self[SmoothMotionKey.self] }
        set { self[SmoothMotionKey.self] = newValue }
    }

    /// Switches the main window to another page, e.g. when a summary card is clicked.
    var navigate: @MainActor (Page) -> Void {
        get { self[NavigateKey.self] }
        set { self[NavigateKey.self] = newValue }
    }
}
