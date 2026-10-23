import AppKit
import IOKit.ps

/// The system events the monitor reacts to: displays sleeping and waking (sampling pauses
/// while nobody can see it) and the charger being plugged in or out (shown right away).
/// Lives as long as the app, so nothing is ever unregistered.
@MainActor
final class SystemEvents {
    var onScreensSleep: () -> Void = {}
    var onScreensWake: () -> Void = {}
    var onPowerSourceChange: () -> Void = {}

    init() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.onScreensSleep() }
        }
        center.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.onScreensWake() }
        }

        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let events = Unmanaged<SystemEvents>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { events.onPowerSourceChange() }
        }, context)?.takeRetainedValue() else { return }
        // Common modes, so it still fires while a menu is open or a window is being dragged.
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }
}
