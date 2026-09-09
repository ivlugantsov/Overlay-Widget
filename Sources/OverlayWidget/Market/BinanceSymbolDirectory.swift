//
//  BinanceSymbolDirectory.swift
//  OverlayWidget
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import Foundation

/// Список реально торгуемых к USDT монет — грузим один раз и кешируем в памяти,
/// дальше просто фильтруем локально по мере ввода (без ключей, публичный REST).
final class BinanceSymbolDirectory {
    private enum Constants {
        static let exchangeInfoURL = URL(string: "https://api.binance.com/api/v3/exchangeInfo")!
        static let priceURL = URL(string: "https://api.binance.com/api/v3/ticker/price")!
    }

    private let session: URLSession
    private var cachedBaseAssets: [String] = []
    private var loadTask: Task<Void, Never>?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(query: String) async -> [String] {
        await ensureLoaded()
        let normalized = query.trimmingCharacters(in: .whitespaces).uppercased()
        guard !normalized.isEmpty else {
            return []
        }
        return cachedBaseAssets.filter { $0.hasPrefix(normalized) }.prefix(15).map { $0 }
    }

    /// Один батч-запрос на все переданные монеты — для превью цены прямо в списке поиска.
    func prices(forBaseAssets baseAssets: [String]) async -> [String: Double] {
        guard !baseAssets.isEmpty else {
            return [:]
        }
        let symbolsJSON = baseAssets.map { "\"\($0.uppercased())USDT\"" }.joined(separator: ",")
        guard var components = URLComponents(url: Constants.priceURL, resolvingAgainstBaseURL: false) else {
            return [:]
        }
        components.queryItems = [URLQueryItem(name: "symbols", value: "[\(symbolsJSON)]")]
        guard let url = components.url,
              let (data, _) = try? await session.data(from: url),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return [:]
        }
        var result: [String: Double] = [:]
        for item in array {
            guard let symbol = item["symbol"] as? String,
                  let priceString = item["price"] as? String,
                  let price = Double(priceString) else {
                continue
            }
            result[String(symbol.dropLast(4))] = price
        }
        return result
    }
}

private extension BinanceSymbolDirectory {
    func ensureLoaded() async {
        guard cachedBaseAssets.isEmpty else {
            return
        }
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task { [weak self] in
            guard let self else {
                return
            }
            await load()
        }
        loadTask = task
        await task.value
    }

    func load() async {
        guard let (data, _) = try? await session.data(from: Constants.exchangeInfoURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let symbols = json["symbols"] as? [[String: Any]] else {
            return
        }
        let assets = symbols.compactMap { entry -> String? in
            guard entry["quoteAsset"] as? String == "USDT",
                  entry["status"] as? String == "TRADING",
                  let base = entry["baseAsset"] as? String else {
                return nil
            }
            return base
        }
        cachedBaseAssets = Array(Set(assets)).sorted()
    }
}
