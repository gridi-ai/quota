import Testing
@testable import QuotaCore

@Test func explicitLanguageSelectionOverridesSystemPreferences() {
    #expect(L10n.resolvedLanguage(selection: "en", preferredLanguages: ["ko-KR"]) == "en")
    #expect(L10n.resolvedLanguage(selection: "ko", preferredLanguages: ["en-US"]) == "ko")
    #expect(L10n.resolvedLanguage(selection: "unsupported", preferredLanguages: ["ko-KR"]) == "en")
}

@Test func systemLanguageUsesFirstSupportedPreferenceOrEnglish() {
    #expect(L10n.resolvedLanguage(selection: "system", preferredLanguages: ["fr-FR", "ko-KR", "en-US"]) == "ko")
    #expect(L10n.resolvedLanguage(selection: "system", preferredLanguages: ["en-GB", "ko-KR"]) == "en")
    #expect(L10n.resolvedLanguage(selection: "system", preferredLanguages: ["ko_KR"]) == "ko")
    #expect(L10n.resolvedLanguage(selection: "system", preferredLanguages: ["ja-JP"]) == "en")
    #expect(L10n.resolvedLanguage(selection: "system", preferredLanguages: []) == "en")
}
