import AppKit
import SwiftUI

extension View {
    /// Keeps the monitor in foreground mode (processes sampled, full refresh rate) while this
    /// view is on screen. With `pausingWhileHidden`, it also lets go while the window is
    /// minimised or completely covered, keeping what's shown for when it's uncovered.
    func foregroundUse(pausingWhileHidden: Bool = false) -> some View {
        modifier(ForegroundUse(pausesWhileHidden: pausingWhileHidden))
    }
}

private struct ForegroundUse: ViewModifier {
    let pausesWhileHidden: Bool

    @Environment(SystemMonitor.self) private var monitor
    @State private var holds = false

    func body(content: Content) -> some View {
        content
            .onAppear { hold(true) }
            .onDisappear { hold(false) }
            .background {
                if pausesWhileHidden {
                    WindowVisibilityReader { visible in hold(visible, keepingData: true) }
                }
            }
    }

    private func hold(_ on: Bool, keepingData: Bool = false) {
        guard on != holds else { return }
        holds = on
        if on { monitor.beginForegroundUse() } else { monitor.endForegroundUse(keepingData: keepingData) }
    }
}

/// Reports whether the hosting window can be seen at all: false while it's minimised, on
/// another Space or completely covered by other windows.
private struct WindowVisibilityReader: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> ReaderView {
        ReaderView()
    }

    func updateNSView(_ view: ReaderView, context: Context) {
        view.onChange = onChange
    }

    final class ReaderView: NSView {
        var onChange: (Bool) -> Void = { _ in }
        private var observer: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observer.map(NotificationCenter.default.removeObserver)
            observer = nil
            guard let window else { return }
            observer = NotificationCenter.default.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.report() }
            }
        }

        private func report() {
            guard let window else { return }
            onChange(window.occlusionState.contains(.visible))
        }
    }
}
