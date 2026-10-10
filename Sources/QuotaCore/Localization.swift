import Foundation

public enum L10n {
    public static func text(_ source: String, bundle: Bundle? = nil, language: String? = nil) -> String {
        let selection = language ?? UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
        let resolved = resolvedLanguage(selection: selection, preferredLanguages: Locale.preferredLanguages)
        #if DEBUG
        let resources: Bundle? = bundle ?? Bundle.module
        #else
        let resources = bundle ?? Bundle.main.resourceURL
            .flatMap { Bundle(url: $0.appendingPathComponent("Quota_QuotaCore.bundle")) }
        #endif
        guard let path = resources?.path(forResource: resolved, ofType: "lproj"),
              let localized = Bundle(path: path) else { return source }
        return localized.localizedString(forKey: source, value: source, table: nil)
    }

    public static func resolvedLanguage(selection: String, preferredLanguages: [String]) -> String {
        if selection != "system" {
            return selection == "ko" ? "ko" : "en"
        }
        for language in preferredLanguages {
            let base = language.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first
            if base == "ko" { return "ko" }
            if base == "en" { return "en" }
        }
        return "en"
    }
}
