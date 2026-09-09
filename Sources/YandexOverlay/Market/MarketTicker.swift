//
//  MarketTicker.swift
//  YandexOverlay
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import Foundation

enum AssetKind: String, Codable, CaseIterable {
    case crypto
    case stock

    func displayName(for language: AppLanguage) -> String {
        switch self {
        case .crypto: return language.strings.cryptoLabel
        case .stock: return language.strings.stockLabel
        }
    }
}

/// Пользовательский символ (не биржевой формат напрямую) — "BTC", "AAPL". Под капотом
/// крипта мапится на пару к USDT (Binance), акции — как есть (Finnhub).
struct MarketTicker: Identifiable, Codable, Equatable {
    let symbol: String
    let kind: AssetKind

    var id: String { "\(kind.rawValue):\(symbol.uppercased())" }

    /// Символ потока Binance, например "btcusdt".
    var binanceStreamSymbol: String { "\(symbol.lowercased())usdt@trade" }

    /// CoinCap раздаёт иконки по детерминированному URL — без ключей и отдельного запроса.
    var cryptoIconURL: URL? {
        guard kind == .crypto else {
            return nil
        }
        return URL(string: "https://assets.coincap.io/assets/icons/\(symbol.lowercased())@2x.png")
    }
}

struct MarketQuote: Identifiable, Equatable {
    let ticker: MarketTicker
    var price: Double?
    /// Для акций логотип узнаём отдельным запросом (Finnhub /stock/profile2) — nil, пока не подтянулся.
    var stockLogoURL: URL?

    var id: String { ticker.id }
}
