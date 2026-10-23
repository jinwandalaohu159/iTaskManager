import AppKit

/// Resolves process icons once per pid so the process list doesn't hit NSWorkspace every second.
@MainActor
final class IconCache {
    private var cache: [pid_t: ProcessIcon] = [:]
    private var apps: [pid_t: NSRunningApplication] = [:]

    /// Refreshes the running-app list and returns the regular (Dock) apps by pid.
    func refreshRegularApps() -> [pid_t: NSRunningApplication] {
        apps = Dictionary(
            NSWorkspace.shared.runningApplications.map { ($0.processIdentifier, $0) },
            uniquingKeysWith: { a, _ in a }
        )
        return apps.filter { $0.value.activationPolicy == .regular }
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
