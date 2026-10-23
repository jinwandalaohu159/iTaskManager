import AppKit
import Observation
import ServiceManagement

/// The root helper that reads usage for processes owned by the system and other users (see
/// Sources/iTaskManagerHelper). macOS only runs it once the user switches it on under
/// System Settings › General › Login Items & Extensions; this tracks and requests that.
@MainActor
@Observable
final class PrivilegedHelper {
    enum State {
        /// Never registered, or removed.
        case off
        /// Registered; waiting for the switch in System Settings.
        case awaitingApproval
        case on
        /// The helper isn't in the app bundle (e.g. a `swift run` build).
        case unavailable
    }

    private(set) var state = State.off

    @ObservationIgnored private let service = SMAppService.daemon(plistName: "\(helperLabel).plist")
    @ObservationIgnored private var watching: Task<Void, Never>?
    private static let helperLabel = "com.rhysmao.iTaskManager.helper"

    init() {
        refresh()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    var isOn: Bool { state == .on }

    func refresh() {
        // A daemon that was never registered also reports `.notFound`, so whether the helper
        // ships in this build is decided by the bundle itself.
        let next: State = if !Self.isBundled {
            .unavailable
        } else {
            switch service.status {
            case .enabled: .on
            case .requiresApproval: .awaitingApproval
            default: .off
            }
        }
        if next != state { state = next }
    }

    private static let isBundled = FileManager.default.fileExists(
        atPath: Bundle.main.bundleURL
            .appending(path: "Contents/Library/LaunchDaemons/\(helperLabel).plist").path
    )

    /// Registers the helper and opens System Settings at the switch, then watches for the
    /// user flipping it.
    func requestAccess() {
        if service.status != .enabled {
            // Fails with "Operation not permitted" until approved; the status says what's next.
            try? service.register()
        }
        refresh()
        if state == .awaitingApproval {
            SMAppService.openSystemSettingsLoginItems()
            watchForApproval()
        }
    }

    func turnOff() {
        try? service.unregister()
        refresh()
    }

    /// System Settings doesn't notify the app, so poll briefly while the user is over there.
    private func watchForApproval() {
        watching?.cancel()
        watching = Task { [weak self] in
            for _ in 0..<300 {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                self.refresh()
                if self.state != .awaitingApproval { return }
            }
        }
    }
}
