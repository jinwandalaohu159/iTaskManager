import SwiftUI

/// All preferences. Shown both as the "设置" page in the main window and in the ⌘, window.
struct SettingsForm: View {
    @Environment(AppSettings.self) private var settings
    @Environment(SystemMonitor.self) private var monitor

    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginError: String?

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section(L("通用")) {
                Picker(L("语言"), selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.nativeName).tag(language)
                    }
                }
                Toggle(L("登录时自动启动"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        loginError = LoginItem.setEnabled(enabled)
                        launchAtLogin = LoginItem.isEnabled
                    }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.secondary)
                }
                Toggle(L("启动时打开主窗口"), isOn: $settings.openWindowAtLaunch)
                Picker(L("默认页面"), selection: $settings.defaultPage) {
                    ForEach(Page.monitoring + [.processes]) { page in
                        Text(page.title).tag(page)
                    }
                }
                Picker(L("外观"), selection: $settings.appearance) {
                    ForEach(AppSettings.Appearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(L("刷新与动画")) {
                Picker(L("刷新频率"), selection: $settings.refreshInterval) {
                    ForEach(AppSettings.refreshIntervals, id: \.self) { interval in
                        Text(L("\(interval, specifier: "%.1f") 秒")).monospacedDigit().tag(interval)
                    }
                }
                Toggle(isOn: $settings.slowRefreshInBackground) {
                    Text(L("仅显示菜单栏时降低刷新频率"))
                        .info(L("主窗口和菜单栏面板都关闭时，刷新间隔变为上面所选的两倍，例如 1.0 秒变为 2.0 秒、5.0 秒变为 10.0 秒。"))
                }
                Toggle(isOn: $settings.smoothMotion) {
                    Text(L("流畅动画"))
                        .info(L("关闭后，图表、数字和进度条直接跳到新值，不做过渡，占用更低。"))
                }
            }

            Section(L("节能")) {
                Toggle(isOn: $settings.efficiencyCoresInBackground) {
                    Text(L("后台运行时只使用能效核"))
                        .info(L("主窗口和菜单栏面板都关闭时，iTaskManager 切换到后台模式，只在能效核上运行，功耗约 2 毫瓦。"))
                }
            }

            Section(L("菜单栏显示")) {
                Toggle(L("CPU 占用"), isOn: $settings.menuBarCPU)
                Toggle(L("内存占用"), isOn: $settings.menuBarMemory)
                Toggle(L("GPU 占用"), isOn: $settings.menuBarGPU)
                Toggle(L("CPU 温度"), isOn: $settings.menuBarCPUTemperature)
                Toggle(L("GPU 温度"), isOn: $settings.menuBarGPUTemperature)
                Toggle(L("整机功耗"), isOn: $settings.menuBarPower)
            }

            Section(L("进程")) {
                Picker(selection: $settings.processCPUScale) {
                    ForEach(AppSettings.CPUScale.allCases) { scale in
                        Text(scale.title).tag(scale)
                    }
                } label: {
                    Text(L("CPU 百分比"))
                        .info(L("按实际消耗的时钟周期计算，核心降频运行时占用也相应更低。占整机：所有核心满频满载为 100%，各进程相加等于总 CPU 占用。占单核：一个性能核满频满载为 100%，多线程程序可以超过 100%。"))
                }
                Toggle(isOn: $settings.groupProcessesByApp) {
                    Text(L("按应用合并辅助进程"))
                        .info(L("把应用的辅助进程（如浏览器的标签页进程）合并到应用名下，展开可查看每一个。"))
                }
                Toggle(isOn: $settings.hideRestrictedProcesses) {
                    Text(L("隐藏无法读取占用的系统进程"))
                        .info(L("未授权读取系统进程时，部分系统进程的占用读不到，打开后不在列表中显示它们。授权后所有进程都能读取，此项不再有影响。"))
                }
                SystemAccessRow()
            }

            Section(L("关于")) {
                UpdateRow()
                Toggle(isOn: $settings.autoUpdate) {
                    Text(L("自动更新"))
                        .info(L("发现新版本后自动下载安装。窗口没有打开时在后台静默完成并重启；窗口打开时显示进度，完成后重启。"))
                }
                LabeledContent(L("芯片"), value: monitor.chip.name)
                LabeledContent(L("核心"), value: L("\(monitor.chip.performanceCount) 性能核 + \(monitor.chip.efficiencyCount) 能效核 · \(monitor.chip.gpuCores) 核 GPU"))
                LabeledContent(L("系统"), value: "macOS \(monitor.chip.osVersion)")
            }
        }
        .formStyle(.grouped)
        // Apply changes that affect sampling right away instead of at the next tick.
        .onChange(of: settings.refreshInterval) { monitor.restart() }
        .onChange(of: settings.groupProcessesByApp) { monitor.restart() }
        .onChange(of: settings.hideRestrictedProcesses) { monitor.restart() }
        .onChange(of: settings.processCPUScale) { monitor.restart() }
    }
}
