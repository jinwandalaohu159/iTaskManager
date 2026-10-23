/// How model values are named and drawn on screen, shared by every page and the menu bar.

extension CoreKind {
    var title: String { self == .performance ? L("性能核") : L("能效核") }
    /// Prefix of a single core's label: P1, P2… / E1, E2…
    var prefix: String { self == .performance ? "P" : "E" }
}

extension BatteryStats {
    var symbolName: String {
        if isCharging || chargingStarting { return "battery.100percent.bolt" }
        // On the charger but not charging (just plugged in, optimized charging, a charge limit).
        if isPluggedIn && !isFullyCharged { return "powerplug.fill" }
        switch percent {
        case ..<0.13: return "battery.0percent"
        case ..<0.38: return "battery.25percent"
        case ..<0.63: return "battery.50percent"
        case ..<0.88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    var stateLabel: String {
        if isFullyCharged && isPluggedIn { return L("已充满") }
        if isCharging { return L("正在充电") }
        if isPluggedIn { return L("已接通电源") }
        return L("使用电池")
    }
}
