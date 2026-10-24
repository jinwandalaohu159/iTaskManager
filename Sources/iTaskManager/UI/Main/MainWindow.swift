import SwiftUI

struct MainWindow: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(AppSettings.self) private var settings
    @Environment(Updater.self) private var updater
    @Environment(\.smoothMotion) private var smooth
    @Environment(\.openSettings) private var openSettings
    @State private var page: Page?
    @State private var columns = NavigationSplitViewVisibility.all
    @State private var promptsForSystemAccess = false

    var body: some View {
        if DevHooks.previewPanel {
            MenuBarPanel().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            splitView
        }
    }

    private var splitView: some View {
        NavigationSplitView(columnVisibility: $columns) {
            List(selection: $page) {
                Section(L("监视")) {
                    ForEach(Page.monitoring) { item in
                        Label(item.title, systemImage: item.symbol).tag(item)
                    }
                }
                Section(L("管理")) {
                    Label(Page.processes.title, systemImage: Page.processes.symbol).tag(Page.processes)
                }
                Section(L("应用", context: "sidebar")) {
                    Label(Page.settings.title, systemImage: Page.settings.symbol).tag(Page.settings)
                }
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
        } detail: {
            // GeometryReader reports the proposed size without measuring its content, so the
            // window's min-size pass stays cheap however much the page animates.
            GeometryReader { _ in
                detail(for: page ?? settings.defaultPage)
                    .id(page)
                    // Opacity only: an offset moves the page's scroll view itself, which leaves it
                    // scrolled a few points under the toolbar, and the toolbar then shows its
                    // scrolled-under background (a grey bar that flickers as pages cross-fade).
                    // The cards still rise in with `reveal`.
                    .transition(.opacity)
            }
            .animation(smooth ? .smooth(duration: 0.32) : nil, value: page)
            .navigationTitle((page ?? settings.defaultPage).title)
        }
        .frame(minWidth: 860, minHeight: 600)
        .environment(\.navigate) { page = $0 }
        .onAppear {
            page = page ?? DevHooks.page ?? settings.defaultPage
            if DevHooks.sidebarHidden { columns = .detailOnly }
            if DevHooks.openSettings { openSettings() }
            if DevHooks.minimumWindow {
                DispatchQueue.main.async {
                    NSApp.windows.first { $0.isVisible && $0.canBecomeMain }?.setContentSize(NSSize(width: 860, height: 600))
                }
            }
            DockPresence.windowOpened()
            let helper = monitor.helper.state
            promptsForSystemAccess = !settings.askedForSystemAccess && helper != .on && helper != .unavailable
        }
        .task { await updater.windowOpened() }
        .sheet(isPresented: $promptsForSystemAccess) { SystemAccessPrompt() }
        .sheet(isPresented: Bindable(updater).presentsSheet) { UpdateSheet() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) { UpdateToolbarButton() }
            // An empty item after the button keeps it off the window's corner.
            ToolbarItem(placement: .primaryAction) { Color.clear.frame(width: 1, height: 1) }
                .sharedBackgroundVisibility(.hidden)
        }
        .onDisappear { DockPresence.windowClosed() }
        // Nothing on screen to keep up to date while hidden: sample like the menu bar does.
        .foregroundUse(pausingWhileHidden: true)
    }

    @ViewBuilder
    private func detail(for page: Page) -> some View {
        switch page {
        case .overview: OverviewPage()
        case .processor: ProcessorPage()
        case .gpu: GPUPage()
        case .memory: MemoryPage()
        case .energy: EnergyPage()
        case .processes: ProcessesPage()
        case .settings:
            // The form's scroll view spans the window (so its edge effect does too); only the
            // sections are held to 680 pt.
            GeometryReader { proxy in
                SettingsForm()
                    .contentMargins(.horizontal, max((proxy.size.width - 680) / 2, 0), for: .scrollContent)
            }
        }
    }
}
