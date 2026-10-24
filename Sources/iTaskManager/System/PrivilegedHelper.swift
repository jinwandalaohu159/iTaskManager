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

    /// The helper's launchd label for this build, from Info.plist; nil when the build has no
    /// helper (e.g. `swift run`). It ends in the helper's own code hash: launchd only lets
    /// that exact helper run under the label it was approved with, and macOS 27 fails to
    /// update the record when the helper changes, so a changed helper gets a new label instead.
    nonisolated static let label = Bundle.main.object(forInfoDictionaryKey: "ITMHelperLabel") as? String

    @ObservationIgnored private let service = label.map { SMAppService.daemon(plistName: "\($0).plist") }
    @ObservationIgnored private var watching: Task<Void, Never>?
    /// The user switched the helper on and hasn't switched it off in the app.
    private static let wantedKey = "privilegedHelperWanted"
    /// The fixed label builds before 1.3 used.
    private static let legacyService = SMAppService.daemon(plistName: "com.rhysmao.iTaskManager.helper.plist")

    init() {
        refresh()
        if state == .off, UserDefaults.standard.bool(forKey: Self.wantedKey) {
            // The helper changed since the user approved the previous one, so it has a new
            // label; carry the approval over.
            try? service?.register()
            refresh()
        }
        let legacy = Self.legacyService.status
        if legacy != .notRegistered && legacy != .notFound {
            Self.legacyService.unregister { _ in }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    var isOn: Bool { state == .on }

    func refresh() {
        let next: State = switch service?.status {
        case nil: .unavailable
        case .enabled: .on
        case .requiresApproval: .awaitingApproval
        default: .off
        }
        if next == .on { UserDefaults.standard.set(true, forKey: Self.wantedKey) }
        if next != state { state = next }
    }

    /// Registers the helper and opens System Settings at the switch, then watches for the
    /// user flipping it.
    func requestAccess() {
        if let service, service.status != .enabled {
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
        UserDefaults.standard.set(false, forKey: Self.wantedKey)
        try? service?.unregister()
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
