import Foundation

/// The app ships its own two-language strings so it needs no resource bundle.
/// Simplified Chinese when the user's first preferred language is Chinese, English otherwise.
public enum AppLanguage: Sendable, Equatable {
    case english
    case chinese

    public static var current: AppLanguage {
        detect(from: Locale.preferredLanguages)
    }

    public static func detect(from preferredLanguages: [String]) -> AppLanguage {
        guard let first = preferredLanguages.first?.lowercased() else { return .english }
        return first.hasPrefix("zh") ? .chinese : .english
    }

    public func pick(en: String, zh: String) -> String {
        self == .chinese ? zh : en
    }
}
