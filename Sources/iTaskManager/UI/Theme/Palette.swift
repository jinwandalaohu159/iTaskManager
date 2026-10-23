import AppKit
import SwiftUI

extension Color {
    /// A color with separate light and dark appearance steps.
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

/// One color per entity, used consistently on every page. Validated for
/// colour-vision deficiency in both appearances.
enum Palette {
    static let cpu = Color(light: 0x2A78D6, dark: 0x3987E5)
    static let pCore = Color(light: 0xEB6834, dark: 0xD95926)
    static let eCore = Color(light: 0x1BAF7A, dark: 0x199E70)
    static let gpu = Color(light: 0x6250D6, dark: 0x9085E9)
    static let memory = Color(light: 0xE87BA4, dark: 0xD55181)
    static let power = Color(light: 0xEDA100, dark: 0xC98500)
    static let other = Color(light: 0xA3A29C, dark: 0x6E6D68)

    static let good = Color(light: 0x0CA30C, dark: 0x0CA30C)
    static let warning = Color(light: 0xFAB219, dark: 0xFAB219)
    static let critical = Color(light: 0xD03B3B, dark: 0xD03B3B)

    static func core(_ kind: CoreKind) -> Color {
        kind == .performance ? pCore : eCore
    }
}
