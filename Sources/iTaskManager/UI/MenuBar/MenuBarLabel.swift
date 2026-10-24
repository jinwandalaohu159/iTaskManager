import AppKit
import SwiftUI

/// The status item: the app's gauge followed by the readings chosen in Settings.
struct MenuBarLabel: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(AppSettings.self) private var settings

    var body: some View {
        // The status item shows a single image, so everything is drawn into one.
        Image(nsImage: MenuBarText.image(items))
    }

    private var items: [MenuBarText.Item] {
        var items: [MenuBarText.Item] = []
        // Temperatures are only read for items that are on, so others don't redraw the item.
        appendReading("CPU", usage: settings.menuBarCPU ? monitor.cpu?.total ?? 0 : nil,
                      temperature: settings.menuBarCPUTemperature ? monitor.temperatures.cpu : nil, to: &items)
        if settings.menuBarMemory { items.append(.init(label: L("内存", context: "menubar"), value: percent(monitor.memory?.usedFraction))) }
        appendReading("GPU", usage: settings.menuBarGPU ? monitor.gpu?.utilization ?? 0 : nil,
                      temperature: settings.menuBarGPUTemperature ? monitor.temperatures.gpu : nil, to: &items)
        if settings.menuBarPower, let watts = monitor.systemWatts { items.append(.init(label: nil, value: Self.watts(watts))) }
        return items
    }

    /// "CPU 12%", "CPU 48°" or both under one label, "CPU 12% 48°".
    private func appendReading(_ label: String, usage: Double?, temperature: SensorGroup?, to items: inout [MenuBarText.Item]) {
        let values = [usage.map { percent($0) }, temperature.map { Self.degrees($0.average) }].compactMap { $0 }
        guard !values.isEmpty else { return }
        items.append(.init(label: label, value: values.joined(separator: " ")))
    }

    /// Whole degrees, two digits wide like the percentages.
    static func degrees(_ celsius: Double) -> String {
        Fmt.padded("\(Int(celsius.rounded()))°", to: 3)
    }

    /// Two digits wide; only a full 100% takes a third.
    private func percent(_ fraction: Double?) -> String {
        Fmt.padded(Fmt.percent(fraction ?? 0), to: 3)
    }

    /// "8.6W" below 10 W, "12W" above — padded with a punctuation space (the width of the
    /// decimal point) so both take the same width.
    static func watts(_ watts: Double) -> String {
        watts < 9.95
            ? String(format: "%.1fW", watts)
            : "\u{2008}" + String(format: "%.0fW", min(watts, 99))
    }
}
