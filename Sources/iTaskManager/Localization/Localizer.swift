import Observation

/// The language currently showing. Views that call `L` read it, so they redraw as soon as it
/// changes. Only `AppSettings` sets it, on the main thread.
@Observable
final class Localizer: @unchecked Sendable {
    static let shared = Localizer()
    var language = AppLanguage.english
}

/// Text in the current language: `L("检查更新")`. Interpolated values pass through, so
/// `L("更新到 \(version)")` looks up "更新到 %@" and puts the version back in.
///
/// `context` tells apart the same Chinese meaning different things in English, such as 关闭
/// for closing a sheet and for switching something off: it looks up "context|key" first.
func L(_ text: LocalizedText, context: String? = nil) -> String {
    let template = switch Localizer.shared.language {
    case .simplifiedChinese: text.key
    case .english: context.flatMap { EnglishStrings.table["\($0)|\(text.key)"] } ?? EnglishStrings.table[text.key] ?? text.key
    }
    return text.filling(template)
}
