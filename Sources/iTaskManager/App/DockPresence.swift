import AppKit

/// The app lives in the menu bar; it appears in the Dock and app switcher only while its
/// main window is open.
@MainActor
enum DockPresence {
    static func windowOpened() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    static func windowClosed() {
        NSApp.setActivationPolicy(.accessory)
    }
}
