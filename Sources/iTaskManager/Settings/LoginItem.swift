import ServiceManagement

/// Launch-at-login, backed by the system's login item registry rather than our own defaults.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Returns an error message when the system refuses the change.
    static func setEnabled(_ enabled: Bool) -> String? {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            return L("设置失败：\(error.localizedDescription)。请先把应用移到“应用程序”文件夹。")
        }
    }
}
