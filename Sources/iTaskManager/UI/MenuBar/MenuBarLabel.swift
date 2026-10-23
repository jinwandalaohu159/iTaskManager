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
        if settings.menuBarCPU { items.append(.init(label: "CPU", value: percent(monitor.cpu?.total))) }
        if settings.menuBarMemory { items.append(.init(label: L("内存", context: "menubar"), value: percent(monitor.memory?.usedFraction))) }
        if settings.menuBarGPU { items.append(.init(label: "GPU", value: percent(monitor.gpu?.utilization))) }
        if settings.menuBarPower, let watts = monitor.systemWatts { items.append(.init(label: nil, value: Self.watts(watts))) }
        return items
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

/// Draws the status item. The menu bar ignores SwiftUI's monospaced-digit setting, and
/// proportional digits make the item — and everything to its left — jitter as values
/// change. With tabular digits and fixed padding the width stays put.
@MainActor
enum MenuBarText {
    struct Item: Equatable {
        let label: String?
        let value: String

        var text: String { label.map { "\($0) \(value)" } ?? value }
    }

    private static let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    private static let appIcon = NSImage(systemSymbolName: "gauge.with.dots.needle.33percent", accessibilityDescription: "iTaskManager")?
        .withSymbolConfiguration(.init(pointSize: NSFont.systemFontSize, weight: .regular))
    private static let itemGap: CGFloat = 8
    private static let appIconGap: CGFloat = 6
    private static var cache: (items: [Item], image: NSImage)?

    static func image(_ items: [Item]) -> NSImage {
        if let cache, cache.items == items { return cache.image }
        let image = items.isEmpty ? (appIcon ?? NSImage()) : render(items)
        image.isTemplate = true   // takes the menu bar's own colour in every appearance
        cache = (items, image)
        return image
    }

    private static func render(_ items: [Item]) -> NSImage {
        let texts = items.map { NSAttributedString(string: $0.text, attributes: [.font: font, .foregroundColor: NSColor.black]) }
        let textHeight = ceil(font.ascender - font.descender)
        let appIconSize = appIcon?.size ?? .zero
        let height = max(textHeight, ceil(appIconSize.height))
        let width = ceil(appIconSize.width) + appIconGap
            + texts.reduce(CGFloat(0)) { $0 + ceil($1.size().width) }
            + itemGap * CGFloat(texts.count - 1)

        return NSImage(size: NSSize(width: ceil(width), height: height), flipped: false) { _ in
            // The app's gauge leads, then each reading.
            appIcon?.draw(in: NSRect(x: 0, y: (height - appIconSize.height) / 2,
                                     width: appIconSize.width, height: appIconSize.height))
            var x = ceil(appIconSize.width) + appIconGap
            for text in texts {
                text.draw(at: NSPoint(x: x, y: (height - textHeight) / 2))
                x += ceil(text.size().width) + itemGap
            }
            return true
        }
    }
}
