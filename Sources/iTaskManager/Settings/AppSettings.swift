import AppKit
import Observation

/// Every user preference, persisted in UserDefaults. The single source of truth for both
/// views and non-UI code such as the monitor.
@MainActor
@Observable
final class AppSettings {
    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark

        var id: String { rawValue }

        var title: String {
            switch self {
            case .system: L("跟随系统")
            case .light: L("浅色")
            case .dark: L("深色")
            }
        }
    }

    /// How a process's CPU percentage is expressed.
    enum CPUScale: String, CaseIterable, Identifiable {
        /// 100% = every core busy, like Windows Task Manager; all processes add up to the total.
        case machine
        /// 100% = one core busy, like Activity Monitor; can exceed 100%.
        case singleCore

        var id: String { rawValue }

        var title: String {
            switch self {
            case .machine: L("占整机")
            case .singleCore: L("占单核")
            }
        }
    }

    static let refreshIntervals: [Double] = [0.5, 1, 2, 5]

    // General
    /// Interface language; English unless chosen otherwise.
    var language: AppLanguage {
        didSet {
            store(language.rawValue, Key.language)
            Localizer.shared.language = language
        }
    }
    var openWindowAtLaunch: Bool { didSet { store(openWindowAtLaunch, Key.openWindowAtLaunch) } }
    var defaultPage: Page { didSet { store(defaultPage.rawValue, Key.defaultPage) } }
    var appearance: Appearance {
        didSet {
            store(appearance.rawValue, Key.appearance)
            applyAppearance()
        }
    }

    // Refresh and motion
    var refreshInterval: Double { didSet { store(refreshInterval, Key.refreshInterval) } }
    /// Refresh at half the chosen rate while only the menu bar is showing.
    var slowRefreshInBackground: Bool { didSet { store(slowRefreshInBackground, Key.slowRefreshInBackground) } }
    var smoothMotion: Bool { didSet { store(smoothMotion, Key.smoothMotion) } }

    // Energy
    /// Run the whole app on the efficiency cores while no window is open.
    var efficiencyCoresInBackground: Bool { didSet { store(efficiencyCoresInBackground, Key.efficiencyCoresInBackground) } }

    // Menu bar
    var menuBarCPU: Bool { didSet { store(menuBarCPU, Key.menuBarCPU) } }
    var menuBarMemory: Bool { didSet { store(menuBarMemory, Key.menuBarMemory) } }
    var menuBarGPU: Bool { didSet { store(menuBarGPU, Key.menuBarGPU) } }
    var menuBarCPUTemperature: Bool { didSet { store(menuBarCPUTemperature, Key.menuBarCPUTemperature) } }
    var menuBarGPUTemperature: Bool { didSet { store(menuBarGPUTemperature, Key.menuBarGPUTemperature) } }
    var menuBarPower: Bool { didSet { store(menuBarPower, Key.menuBarPower) } }

    // Processes
    var groupProcessesByApp: Bool { didSet { store(groupProcessesByApp, Key.groupProcessesByApp) } }
    var hideRestrictedProcesses: Bool { didSet { store(hideRestrictedProcesses, Key.hideRestrictedProcesses) } }
    var processCPUScale: CPUScale { didSet { store(processCPUScale.rawValue, Key.processCPUScale) } }
    /// Install new versions on their own: quietly while no window is open, with progress shown
    /// while one is. Off, new versions are still found and offered.
    var autoUpdate: Bool { didSet { store(autoUpdate, Key.autoUpdate) } }
    /// The first-launch prompt about reading system processes has been answered.
    var askedForSystemAccess: Bool { didSet { store(askedForSystemAccess, Key.askedForSystemAccess) } }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        func bool(_ key: String, _ fallback: Bool) -> Bool { defaults.object(forKey: key) as? Bool ?? fallback }

        let language = defaults.string(forKey: Key.language).flatMap(AppLanguage.init(rawValue:)) ?? .english
        self.language = language
        Localizer.shared.language = language
        openWindowAtLaunch = bool(Key.openWindowAtLaunch, true)
        defaultPage = defaults.string(forKey: Key.defaultPage).flatMap(Page.init(rawValue:)) ?? .overview
        appearance = defaults.string(forKey: Key.appearance).flatMap(Appearance.init(rawValue:)) ?? .system

        let interval = defaults.double(forKey: Key.refreshInterval)
        refreshInterval = Self.refreshIntervals.contains(interval) ? interval : 1
        slowRefreshInBackground = bool(Key.slowRefreshInBackground, true)
        // Migrates the earlier "smoothCharts" preference.
        smoothMotion = bool(Key.smoothMotion, bool("smoothCharts", true))
        efficiencyCoresInBackground = bool(Key.efficiencyCoresInBackground, true)

        menuBarCPU = bool(Key.menuBarCPU, true)
        menuBarMemory = bool(Key.menuBarMemory, false)
        menuBarGPU = bool(Key.menuBarGPU, false)
        menuBarCPUTemperature = bool(Key.menuBarCPUTemperature, false)
        menuBarGPUTemperature = bool(Key.menuBarGPUTemperature, false)
        menuBarPower = bool(Key.menuBarPower, true)

        groupProcessesByApp = bool(Key.groupProcessesByApp, true)
        hideRestrictedProcesses = bool(Key.hideRestrictedProcesses, false)
        processCPUScale = defaults.string(forKey: Key.processCPUScale).flatMap(CPUScale.init(rawValue:)) ?? .machine
        askedForSystemAccess = bool(Key.askedForSystemAccess, false)
        // Carries over the earlier "check for updates automatically" choice.
        autoUpdate = bool(Key.autoUpdate, bool("autoCheckUpdates", true))

        applyAppearance()
    }

    func applyAppearance() {
        NSApplication.shared.appearance = switch appearance {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    private func store(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
    }

    private enum Key {
        static let language = "language"
        static let openWindowAtLaunch = "openWindowAtLaunch"
        static let defaultPage = "defaultPage"
        static let appearance = "appearance"
        static let refreshInterval = "refreshInterval"
        static let slowRefreshInBackground = "slowRefreshInBackground"
        static let smoothMotion = "smoothMotion"
        static let efficiencyCoresInBackground = "efficiencyCoresInBackground"
        static let menuBarCPU = "menuBarCPU"
        static let menuBarMemory = "menuBarMemory"
        static let menuBarGPU = "menuBarGPU"
        static let menuBarCPUTemperature = "menuBarCPUTemperature"
        static let menuBarGPUTemperature = "menuBarGPUTemperature"
        static let menuBarPower = "menuBarPower"
        static let groupProcessesByApp = "groupProcessesByApp"
        static let hideRestrictedProcesses = "hideRestrictedProcesses"
        static let processCPUScale = "processCPUScale"
        static let askedForSystemAccess = "askedForSystemAccess"
        static let autoUpdate = "autoUpdate"
    }
}
