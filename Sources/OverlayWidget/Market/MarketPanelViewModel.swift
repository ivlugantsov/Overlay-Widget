//
//  MarketPanelViewModel.swift
//  OverlayWidget
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import Foundation

@MainActor
final class MarketPanelViewModel {
    private enum Constants {
        static let stockPollDelayNanos: UInt64 = 30_000_000_000
    }

    let viewInput = MarketPanelViewInput()

    private let settingsStore: MarketSettingsStore
    private let cryptoFeed: CryptoFeeding
    private let stockFeed: StockQuoting

    private var cryptoTask: Task<Void, Never>?
    private var stockPollTask: Task<Void, Never>?
    private var prices: [String: Double] = [:]
    private var stockLogoURLs: [String: URL] = [:]

    init(settingsStore: MarketSettingsStore, cryptoFeed: CryptoFeeding, stockFeed: StockQuoting) {
        self.settingsStore = settingsStore
        self.cryptoFeed = cryptoFeed
        self.stockFeed = stockFeed
        viewInput.isEnabled = settingsStore.isEnabled
        rebuildQuotes()
    }

    func start() {
        guard viewInput.isEnabled else {
            return
        }
        subscribeAllCrypto()
        startCryptoListening()
        startStockPolling()
    }

    func stop() {
        cryptoTask?.cancel()
        stockPollTask?.cancel()
    }

    func setEnabled(_ enabled: Bool) {
        viewInput.isEnabled = enabled
        settingsStore.isEnabled = enabled
        if enabled {
            start()
        } else {
            stop()
        }
    }

    func addTicker(symbol: String, kind: AssetKind) {
        let ticker = MarketTicker(symbol: symbol.uppercased(), kind: kind)
        var tickers = settingsStore.tickers
        guard !tickers.contains(ticker) else {
            return
        }
        tickers.append(ticker)
        settingsStore.tickers = tickers
        rebuildQuotes()

        guard viewInput.isEnabled else {
            return
        }
        if kind == .crypto {
            cryptoFeed.subscribe(streamSymbols: [ticker.binanceStreamSymbol])
        } else {
            Task { await pollStock(ticker) }
        }
    }

    func removeTicker(_ ticker: MarketTicker) {
        var tickers = settingsStore.tickers
        tickers.removeAll { $0 == ticker }
        settingsStore.tickers = tickers
        prices[ticker.id] = nil
        rebuildQuotes()

        if ticker.kind == .crypto {
            cryptoFeed.unsubscribe(streamSymbols: [ticker.binanceStreamSymbol])
        }
    }
}

private extension MarketPanelViewModel {
    func subscribeAllCrypto() {
        let streamSymbols = settingsStore.tickers.filter { $0.kind == .crypto }.map(\.binanceStreamSymbol)
        cryptoFeed.subscribe(streamSymbols: streamSymbols)
    }

    func startCryptoListening() {
        cryptoTask = Task { [weak self] in
            guard let self else {
                return
            }
            for await update in cryptoFeed.priceUpdates() {
                guard let ticker = settingsStore.tickers.first(where: {
                    $0.kind == .crypto && $0.binanceStreamSymbol.hasPrefix(update.symbol)
                }) else {
                    continue
                }
                apply(price: update.price, toTickerID: ticker.id)
            }
        }
    }

    func startStockPolling() {
        stockPollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else {
                    return
                }
                for ticker in settingsStore.tickers where ticker.kind == .stock {
                    await pollStock(ticker)
                }
                try? await Task.sleep(nanoseconds: Constants.stockPollDelayNanos)
            }
        }
    }

    func pollStock(_ ticker: MarketTicker) async {
        guard let price = await stockFeed.quote(symbol: ticker.symbol) else {
            return
        }
        apply(price: price, toTickerID: ticker.id)
    }

    /// Binance шлёт апдейт на каждую сделку — часто с той же ценой подряд. Если ничего не
    /// изменилось, не трогаем @Published quotes вообще: это лишний objectWillChange и
    /// перерисовка панели ради нуля видимых изменений.
    func apply(price: Double, toTickerID id: String) {
        guard prices[id] != price else {
            return
        }
        prices[id] = price
        guard let index = viewInput.quotes.firstIndex(where: { $0.id == id }) else {
            return
        }
        viewInput.quotes[index].price = price
    }

    func rebuildQuotes() {
        viewInput.quotes = settingsStore.tickers.map {
            MarketQuote(ticker: $0, price: prices[$0.id], stockLogoURL: stockLogoURLs[$0.id])
        }
        for ticker in settingsStore.tickers where ticker.kind == .stock && stockLogoURLs[ticker.id] == nil {
            fetchStockLogo(ticker)
        }
    }

    func fetchStockLogo(_ ticker: MarketTicker) {
        Task { [weak self] in
            guard let self, let url = await stockFeed.logoURL(symbol: ticker.symbol) else {
                return
            }
            stockLogoURLs[ticker.id] = url
            guard let index = viewInput.quotes.firstIndex(where: { $0.id == ticker.id }) else {
                return
            }
            viewInput.quotes[index].stockLogoURL = url
        }
    }
}
