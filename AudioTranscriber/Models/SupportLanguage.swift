import Foundation

enum SupportLanguage: String, CaseIterable {
    case auto, ja, en, zh, es, fr, de, ru, ar, pt, ko, it, hi

    var nativeName: String {
        switch self {
        case .auto: return L10n.Common.SupportLanguage.auto
        case .en: return "English"
        case .ja: return "日本語"
        case .zh: return "中文"
        case .es: return "Español"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .ru: return "Русский"
        case .ar: return "العربية"
        case .pt: return "Português"
        case .ko: return "한국어"
        case .it: return "Italiano"
        case .hi: return "हिंदी"
        }
    }

    static var `default`: SupportLanguage {
        for id in Locale.preferredLanguages {
            let code = String(id.prefix(2))
            if let lang = SupportLanguage(rawValue: code) {
                return lang
            }
        }
        return .en
    }
}
