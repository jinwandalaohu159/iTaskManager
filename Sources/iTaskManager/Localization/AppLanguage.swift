import Foundation

/// The languages the interface is written in. Text in the source is Simplified Chinese;
/// `EnglishStrings` has the English for each.
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    /// Always in its own language, so it can be found whichever is showing.
    var nativeName: String {
        switch self {
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }
}
