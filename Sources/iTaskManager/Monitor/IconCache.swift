import AppKit

/// Resolves process icons once per pid so the process list doesn't hit NSWorkspace every second.
@MainActor
final class IconCache {
    private var cache: [pid_t: ProcessIcon] = [:]
    private var apps: [pid_t: NSRunningApplication] = [:]
    private var regularApps: [pid_t: NSRunningApplication] = [:]
    /// The running-app list only changes when an app launches or quits, so it's re-read then
    /// rather than on every sample.
    private var appsChanged = true

    init() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.appsChanged = true }
            }
        }
    }

    /// The regular (Dock) apps by pid, re-read only after an app launched or quit.
    func runningRegularApps() -> [pid_t: NSRunningApplication] {
        guard appsChanged else { return regularApps }
        appsChanged = false
        apps = Dictionary(
            NSWorkspace.shared.runningApplications.map { ($0.processIdentifier, $0) },
            uniquingKeysWith: { a, _ in a }
        )
        regularApps = apps.filter { $0.value.activationPolicy == .regular }
        return regularApps
    }

    func icon(for pid: pid_t, path: String?) -> ProcessIcon {
        if let cached = cache[pid] { return cached }
        let icon: ProcessIcon
        if let image = apps[pid]?.icon {
            icon = .image(image)
        } else if let path, let bundle = Self.enclosingAppBundle(of: path) {
            icon = .image(NSWorkspace.shared.icon(forFile: bundle))
        } else {
            icon = .symbol("gearshape.2")
        }
        cache[pid] = icon
        return icon
    }

    func prune(keeping pids: Set<pid_t>) {
        cache = cache.filter { pids.contains($0.key) }
    }

    private static func enclosingAppBundle(of path: String) -> String? {
        guard let range = path.range(of: ".app/") else { return nil }
        return String(path[..<range.lowerBound]) + ".app"
    }
}
