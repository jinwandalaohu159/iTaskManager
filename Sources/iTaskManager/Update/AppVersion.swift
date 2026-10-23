import Foundation

/// A dotted version like "1.1" or "1.0.2", compared number by number ("1.10" > "1.9").
struct AppVersion: Comparable, Sendable, CustomStringConvertible {
    let parts: [Int]

    /// Accepts a leading "v", as in release tags ("v1.1.0").
    init?(_ text: String) {
        let trimmed = text.hasPrefix("v") || text.hasPrefix("V") ? String(text.dropFirst()) : text
        let parts = trimmed.split(separator: ".").map { Int($0) }
        guard !parts.isEmpty, parts.allSatisfy({ $0 != nil }) else { return nil }
        self.parts = parts.compactMap { $0 }
    }

    /// This build's CFBundleShortVersionString.
    static let current = AppVersion(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") ?? AppVersion("0")!

    static func < (a: AppVersion, b: AppVersion) -> Bool {
        for i in 0..<max(a.parts.count, b.parts.count) {
            let x = i < a.parts.count ? a.parts[i] : 0
            let y = i < b.parts.count ? b.parts[i] : 0
            if x != y { return x < y }
        }
        return false
    }

    static func == (a: AppVersion, b: AppVersion) -> Bool { !(a < b) && !(b < a) }

    /// Trailing ".0"s dropped below two parts: "1.1", "1.0.2".
    var description: String {
        var shown = parts
        while shown.count > 2, shown.last == 0 { shown.removeLast() }
        if shown.count == 1 { shown.append(0) }
        return shown.map(String.init).joined(separator: ".")
    }
}
