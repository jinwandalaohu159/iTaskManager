import Foundation

/// Environment switches for checking the UI from a script (screenshots, layout checks).
/// None are set in normal use.
///
///   ITM_PAGE=energy        open the main window on a page
///   ITM_SIDEBAR=hidden     start with the sidebar collapsed
///   ITM_PREVIEW=panel      show the menu bar panel inside the main window
///   ITM_OPEN_SETTINGS=1    open the ⌘, settings window at launch
///   ITM_WINDOW=min         shrink the main window to its minimum size
///   ITM_UPDATE_FEED=URL    read the "latest release" JSON from here instead of GitHub
///   ITM_UPDATE_NOW=1       start installing as soon as a newer version is found
enum DevHooks {
    private static let environment = ProcessInfo.processInfo.environment

    static var page: Page? { environment["ITM_PAGE"].flatMap(Page.init(rawValue:)) }
    static var sidebarHidden: Bool { environment["ITM_SIDEBAR"] == "hidden" }
    static var previewPanel: Bool { environment["ITM_PREVIEW"] == "panel" }
    static var openSettings: Bool { environment["ITM_OPEN_SETTINGS"] == "1" }
    static var minimumWindow: Bool { environment["ITM_WINDOW"] == "min" }
    static var installUpdateWhenFound: Bool { environment["ITM_UPDATE_NOW"] == "1" }
    static var updateFeed: URL? { environment["ITM_UPDATE_FEED"].flatMap(URL.init(string:)) }
}
