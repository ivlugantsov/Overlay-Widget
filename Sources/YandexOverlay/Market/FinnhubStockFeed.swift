//
//  FinnhubStockFeed.swift
//  YandexOverlay
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import Foundation

struct StockSearchResult: Identifiable, Equatable {
    let symbol: String
    let description: String

    var id: String { symbol }
}

protocol StockQuoting {
    func quote(symbol: String) async -> Double?
    /// Живой поиск по реальным тикерам Finnhub — чтобы нельзя было добавить
    /// несуществующий/опечатанный символ в список.
    func search(query: String) async -> [StockSearchResult]
    /// Логотип компании — отдельный эндпоинт, не приходит вместе с поиском/котировкой.
    func logoURL(symbol: String) async -> URL?
}

/// REST-поллинг вместо сокета — свежести раз в 30-40 сек достаточно, а бесплатный
/// тариф Finnhub такому объёму запросов ничего не должен.
final class FinnhubStockFeed: StockQuoting {
    private enum Constants {
        static let quoteURL = URL(string: "https://finnhub.io/api/v1/quote")!
        static let searchURL = URL(string: "https://finnhub.io/api/v1/search")!
        static let profileURL = URL(string: "https://finnhub.io/api/v1/stock/profile2")!
    }

    private let tokenStore: TokenStoring
    private let session: URLSession

    init(tokenStore: TokenStoring, session: URLSession = .shared) {
        self.tokenStore = tokenStore
        self.session = session
    }

    func quote(symbol: String) async -> Double? {
        guard let token = tokenStore.loadToken(),
              var components = URLComponents(url: Constants.quoteURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "symbol", value: symbol.uppercased()),
            URLQueryItem(name: "token", value: token)
        ]
        guard let url = components.url,
              let (data, response) = try? await session.data(from: url),
              let statusCode = (response as? HTTPURLResponse)?.statusCode,
              (200...299).contains(statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let price = json["c"] as? Double, price > 0 else {
            return nil
        }
        return price
    }

    func search(query: String) async -> [StockSearchResult] {
        guard !query.isEmpty, let token = tokenStore.loadToken(),
              var components = URLComponents(url: Constants.searchURL, resolvingAgainstBaseURL: false) else {
            return []
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "token", value: token)
        ]
        guard let url = components.url,
              let (data, response) = try? await session.data(from: url),
              let statusCode = (response as? HTTPURLResponse)?.statusCode,
              (200...299).contains(statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["result"] as? [[String: Any]] else {
            return []
        }
        return results.compactMap { item -> StockSearchResult? in
            guard let symbol = item["symbol"] as? String,
                  let description = item["description"] as? String else {
                return nil
            }
            return StockSearchResult(symbol: symbol, description: description)
        }.prefix(15).map { $0 }
    }

    func logoURL(symbol: String) async -> URL? {
        guard let token = tokenStore.loadToken(),
              var components = URLComponents(url: Constants.profileURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "symbol", value: symbol.uppercased()),
            URLQueryItem(name: "token", value: token)
        ]
        guard let url = components.url,
              let (data, response) = try? await session.data(from: url),
              let statusCode = (response as? HTTPURLResponse)?.statusCode,
              (200...299).contains(statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let logo = json["logo"] as? String, !logo.isEmpty else {
            return nil
        }
        return URL(string: logo)
    }
}
