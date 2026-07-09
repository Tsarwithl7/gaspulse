import Foundation

/// Returns the English or Chinese string depending on the user's language preference.
/// Views must hold `@AppStorage("appLanguage") private var lang: String`
/// so SwiftUI can re-render when the preference changes.
func loc(_ en: String, _ zh: String) -> String {
    UserDefaults.standard.string(forKey: "appLanguage") == "en" ? en : zh
}
