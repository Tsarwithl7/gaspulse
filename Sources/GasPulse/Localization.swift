import Foundation

/// Returns the string for the current app language.
/// Falls back to English when a Spanish translation is not provided.
/// Views MUST hold `@AppStorage("appLanguage") private var lang: String`
/// so SwiftUI re-renders when the preference changes.
func loc(_ en: String, _ zh: String, _ es: String? = nil) -> String {
    let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
    switch lang {
    case "zh": return zh
    case "es": return es ?? en
    default:   return en
    }
}
