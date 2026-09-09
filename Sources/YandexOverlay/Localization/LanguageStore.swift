//
//  LanguageStore.swift
//  YandexOverlay
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import Foundation

/// ObservableObject, а не просто хранилище — SwiftUI-вьюхи держат её через
/// @EnvironmentObject и сами перерисовываются при смене языка.
final class LanguageStore: ObservableObject {
    private enum Keys {
        static let language = "app.language"
    }

    private let defaults: UserDefaults

    @Published var current: AppLanguage

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Keys.language), let language = AppLanguage(rawValue: raw) {
            current = language
        } else {
            current = (Locale.preferredLanguages.first ?? "en").hasPrefix("ru") ? .ru : .en
        }
    }

    func setLanguage(_ language: AppLanguage) {
        current = language
        defaults.set(language.rawValue, forKey: Keys.language)
    }
}
