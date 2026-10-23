import AppKit

/// Acting on other processes: ending them and locating their executables.
enum ProcessControl {
    enum TerminateResult {
        case ok, denied, failed
    }

    /// Apps get a polite `terminate()` (so they can ask to save); other processes get signals.
    @MainActor
    static func terminate(pid: pid_t, force: Bool) -> TerminateResult {
        if let app = NSRunningApplication(processIdentifier: pid) {
            return (force ? app.forceTerminate() : app.terminate()) ? .ok : .failed
        }
        if kill(pid, force ? SIGKILL : SIGTERM) == 0 { return .ok }
        return errno == EPERM ? .denied : .failed
    }

    static func executablePath(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(decoding: buffer.prefix { $0 != 0 }.map(UInt8.init), as: UTF8.self)
    }
}
