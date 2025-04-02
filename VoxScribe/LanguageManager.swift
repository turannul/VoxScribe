//
//  LanguageManager.swift
//  VoxScribe
//
//  Created by Turann_ on 2.04.2025.
//

import Speech
import Foundation

class LanguageManager: ObservableObject {
    @Published var availableLanguages: [SupportedLanguage] = []
    @Published var selectedLanguage: SupportedLanguage
    
    init() {
        let loadedLanguages = Self.loadAvailableLanguages()
        self.availableLanguages = loadedLanguages
        self.selectedLanguage = Self.autoDetectSystemLanguage(availableLanguages: loadedLanguages)
    }
    
    private static func loadAvailableLanguages() -> [SupportedLanguage] {
        let locales = SFSpeechRecognizer.supportedLocales()
        
        return locales.sorted {
            let name1 = $0.localizedString(forIdentifier: $0.identifier) ?? ""
            let name2 = $1.localizedString(forIdentifier: $1.identifier) ?? ""
            return name1 < name2
        }.map { locale in
            let code = locale.identifier
            let name = locale.localizedString(forIdentifier: code) ?? code
            return SupportedLanguage(name: name, code: code)
        }
    }
    
    private static func autoDetectSystemLanguage(availableLanguages: [SupportedLanguage]) -> SupportedLanguage {
        let systemCode = Locale.current.identifier.replacingOccurrences(of: "_", with: "-").lowercased()
        
        // Try full match first (e.g. "en-US")
        if let match = availableLanguages.first(where: { $0.code.lowercased() == systemCode }) {
            return match
        }
        
        // Try base language match (e.g. "en" if system is "en-GB")
        let baseCode = String(systemCode.prefix(2))
        if let match = availableLanguages.first(where: { $0.code.lowercased().hasPrefix(baseCode) }) {
            return match
        }
        
        // Fallback to en-US or first available
        return availableLanguages.first { $0.code == "en-US" } ?? availableLanguages.first ?? SupportedLanguage(name: "English", code: "en-US")
    }
    
    func setLanguage(code: String) {
        if let language = availableLanguages.first(where: { $0.code == code }) {
            self.selectedLanguage = language
        }
    }
}

struct SupportedLanguage: Identifiable, Hashable {
    let id = UUID()
    let name: String  // Will show full names eg: "English (United States)"
    let code: String   // Locale code eg:7 "en-US"
}
