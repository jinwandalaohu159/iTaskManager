import Darwin

/// Darwin background mode lowers priority, throttles I/O and, on Apple Silicon, keeps every
/// thread of the process on the efficiency cores.
enum PowerMode {
    static func setBackground(_ enabled: Bool) {
        setpriority(PRIO_DARWIN_PROCESS, 0, enabled ? PRIO_DARWIN_BG : 0)
    }
}
