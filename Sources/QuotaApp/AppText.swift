import Foundation
import QuotaCore

func tr(_ source: String, _ arguments: CVarArg...) -> String {
    let bundle: Bundle?
    #if DEBUG
    bundle = .module
    #else
    bundle = Bundle.main.resourceURL.flatMap {
        Bundle(url: $0.appendingPathComponent("Quota_QuotaApp.bundle"))
    }
    #endif
    let text = L10n.text(source, bundle: bundle)
    return arguments.isEmpty ? text : String(format: text, locale: appLocale, arguments: arguments)
}

var appLocale: Locale {
    Locale(identifier: L10n.resolvedLanguage(
        selection: UserDefaults.standard.string(forKey: "appLanguage") ?? "system",
        preferredLanguages: Locale.preferredLanguages
    ))
}
