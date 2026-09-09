//
//  MarketSettingsStore.swift
//  OverlayWidget
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import Foundation

/// Список тикеров и вкл/выкл панели — не секрет, поэтому UserDefaults, а не Keychain
/// (сам API-токен Finnhub хранится отдельно через KeychainService).
final class MarketSettingsStore {
    private enum Keys {
        static let isEnabled = "market.isEnabled"
        static let tickers = "market.tickers"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Keys.isEnabled) }
        set { defaults.set(newValue, forKey: Keys.isEnabled) }
    }

    var tickers: [MarketTicker] {
        get {
            guard let data = defaults.data(forKey: Keys.tickers),
                  let decoded = try? JSONDecoder().decode([MarketTicker].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else {
                return
            }
            defaults.set(data, forKey: Keys.tickers)
        }
    }
}
