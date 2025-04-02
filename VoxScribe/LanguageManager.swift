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
    @Published var selectedLanguage: SupportedLanguage = SupportedLanguage.systemLanguage
    
    init() {
        loadAvailableLanguages()
    }
    
    func loadAvailableLanguages() {
        var languages: [SupportedLanguage] = [SupportedLanguage.systemLanguage]
        
        // Get all available speech recognizers
        let locales = SFSpeechRecognizer.supportedLocales()
        
        // Sort locales by their display name
        let sortedLocales = locales.sorted {
            $0.localizedString(forIdentifier: $0.identifier) ?? "" < $1.localizedString(forIdentifier: $1.identifier) ?? ""
        }
        
        // Convert to our SupportedLanguage model
        for locale in sortedLocales {
            let name = locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
            languages.append(SupportedLanguage(name: name, code: locale.identifier))
        }
        
        self.availableLanguages = languages
    }
    
    func setLanguage(code: String) {
        if let language = availableLanguages.first(where: { $0.code == code }) {
            self.selectedLanguage = language
        }
    }
}
