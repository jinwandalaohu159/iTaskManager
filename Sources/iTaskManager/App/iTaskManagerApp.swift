import SwiftUI

@main
struct iTaskManagerApp: App {
    @State private var settings: AppSettings
    @State private var monitor: SystemMonitor
    @State private var updater: Updater

    init() {
        let settings = AppSettings()
        let updater = Updater()
        updater.startAutomaticChecks { settings.autoCheckUpdates }
        _settings = State(initialValue: settings)
        _monitor = State(initialValue: SystemMonitor(settings: settings))
        _updater = State(initialValue: updater)
    }

    var body: some Scene {
        Window("iTaskManager", id: "main") {
            MainWindow()
                .appEnvironment(settings: settings, monitor: monitor, updater: updater)
        }
        .defaultSize(width: 1120, height: 780)
        .defaultLaunchBehavior(settings.openWindowAtLaunch ? .presented : .suppressed)

        MenuBarExtra {
            MenuBarPanel()
                .appEnvironment(settings: settings, monitor: monitor, updater: updater)
        } label: {
            MenuBarLabel()
                .appEnvironment(settings: settings, monitor: monitor, updater: updater)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsForm()
                .frame(width: 520, height: 640)
                .appEnvironment(settings: settings, monitor: monitor, updater: updater)
        }
    }
}

private extension View {
    func appEnvironment(settings: AppSettings, monitor: SystemMonitor, updater: Updater) -> some View {
        environment(settings)
            .environment(monitor)
            .environment(updater)
            .environment(\.smoothMotion, settings.smoothMotion)
            .environment(\.locale, settings.language.locale)
    }
}
