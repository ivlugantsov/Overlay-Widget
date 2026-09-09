//
//  SettingsView.swift
//  OverlayWidget
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import AppKit
import SwiftUI

struct SettingsView: View {
    private enum Constants {
        /// Публичный client_id того же типа, что использует open-source yandex-music-api —
        /// это не наш сервер, просто стандартная точка входа implicit OAuth-флоу Яндекса.
        static let yandexOAuthURL = URL(
            string: "https://oauth.yandex.ru/authorize?response_type=token&client_id=23cabbbdc6cd418abb4b39c32c41195d"
        )!
        static let finnhubRegisterURL = URL(string: "https://finnhub.io/register")!
    }

    private let yandexTokenStore: TokenStoring
    private let finnhubTokenStore: TokenStoring
    private let playerViewModel: PlayerViewModel
    private let marketViewModel: MarketPanelViewModel
    private let cryptoDirectory: BinanceSymbolDirectory
    private let stockSearch: StockQuoting
    @ObservedObject private var playerViewInput: PlayerViewInput
    @ObservedObject private var marketViewInput: MarketPanelViewInput
    @ObservedObject private var launchAtLoginController: LaunchAtLoginController
    @EnvironmentObject private var languageStore: LanguageStore

    @State private var yandexToken: String
    @State private var didSaveYandexToken = false
    @State private var finnhubToken: String
    @State private var didSaveFinnhubToken = false
    @State private var newTickerSymbol = ""
    @State private var newTickerKind: AssetKind = .crypto
    @State private var cryptoResults: [String] = []
    @State private var stockResults: [StockSearchResult] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var priceTask: Task<Void, Never>?
    @State private var searchPrices: [String: Double] = [:]
    @State private var isSearching = false

    private var strings: Strings { languageStore.current.strings }

    init(
        yandexTokenStore: TokenStoring,
        finnhubTokenStore: TokenStoring,
        playerViewModel: PlayerViewModel,
        marketViewModel: MarketPanelViewModel,
        cryptoDirectory: BinanceSymbolDirectory,
        stockSearch: StockQuoting,
        launchAtLoginController: LaunchAtLoginController
    ) {
        self.yandexTokenStore = yandexTokenStore
        self.finnhubTokenStore = finnhubTokenStore
        self.playerViewModel = playerViewModel
        self.marketViewModel = marketViewModel
        self.cryptoDirectory = cryptoDirectory
        self.stockSearch = stockSearch
        self.launchAtLoginController = launchAtLoginController
        playerViewInput = playerViewModel.viewInput
        marketViewInput = marketViewModel.viewInput
        _yandexToken = State(initialValue: yandexTokenStore.loadToken() ?? "")
        _finnhubToken = State(initialValue: finnhubTokenStore.loadToken() ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                widgetsSection
                Divider()
                languageSection
                Divider()
                yandexSection
                Divider()
                marketSection
                Divider()
                infoSection
            }
            .padding(20)
        }
        .frame(width: 340, height: 560)
    }
}

// MARK: - Widgets

private extension SettingsView {
    var widgetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(strings.widgetsTitle)
                .font(.headline)
            Text(strings.widgetsDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Toggle(strings.playerToggle, isOn: Binding(
                get: { playerViewInput.isVisible },
                set: { playerViewModel.setVisible($0) }
            ))
            Toggle(strings.marketPanelToggle, isOn: Binding(
                get: { marketViewInput.isEnabled },
                set: { marketViewModel.setEnabled($0) }
            ))

            Divider()

            Toggle(strings.launchAtLoginToggle, isOn: Binding(
                get: { launchAtLoginController.isEnabled },
                set: { launchAtLoginController.setEnabled($0) }
            ))
        }
    }
}

// MARK: - Language

private extension SettingsView {
    var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(strings.languageTitle)
                .font(.headline)

            Picker("", selection: Binding(
                get: { languageStore.current },
                set: { languageStore.setLanguage($0) }
            )) {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            // Без ограниченной ширины сегментированный контрол внутри ScrollView не может
            // сойтись к стабильному размеру и уходит в бесконечный цикл layout — грузит
            // ядро на 100% всё время, пока окно настроек открыто.
            .frame(width: 300)
        }
    }
}

// MARK: - Yandex

private extension SettingsView {
    var yandexSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(strings.yandexTokenTitle)
                .font(.headline)
            Text(strings.yandexTokenDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button(strings.getTokenButton) {
                NSWorkspace.shared.open(Constants.yandexOAuthURL)
            }

            Text(strings.yandexTokenInstructions)
                .font(.caption)
                .foregroundStyle(.secondary)

            SecureField(strings.tokenFieldPlaceholder, text: $yandexToken)
                .textFieldStyle(.roundedBorder)

            HStack {
                if didSaveYandexToken {
                    Text(strings.savedLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(strings.saveButton) {
                    yandexTokenStore.save(token: yandexToken)
                    didSaveYandexToken = true
                }
                .disabled(yandexToken.isEmpty)
            }
        }
    }
}

// MARK: - Market panel

private extension SettingsView {
    var marketSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(strings.marketSourcesDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(strings.tickersTitle)
                .font(.subheadline.weight(.semibold))

            tickerSearchRow
                .zIndex(1)

            if marketViewInput.quotes.isEmpty {
                Text(strings.tickersEmpty)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            ForEach(marketViewInput.quotes) { quote in
                HStack {
                    Text("\(quote.ticker.symbol) · \(quote.ticker.kind.displayName(for: languageStore.current))")
                        .font(.system(size: 12))
                    Spacer()
                    Button {
                        marketViewModel.removeTicker(quote.ticker)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            Text(strings.finnhubTokenTitle)
                .font(.subheadline.weight(.semibold))

            Button(strings.getFinnhubTokenButton) {
                NSWorkspace.shared.open(Constants.finnhubRegisterURL)
            }
            Text(strings.finnhubTokenInstructions)
                .font(.caption)
                .foregroundStyle(.secondary)

            SecureField(strings.finnhubTokenFieldPlaceholder, text: $finnhubToken)
                .textFieldStyle(.roundedBorder)

            HStack {
                if didSaveFinnhubToken {
                    Text(strings.savedLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(strings.saveButton) {
                    finnhubTokenStore.save(token: finnhubToken)
                    didSaveFinnhubToken = true
                }
                .disabled(finnhubToken.isEmpty)
            }
        }
    }

    /// Добавление — только выбором из живого поиска, чтобы нельзя было занести
    /// в список опечатку или несуществующий тикер. Результаты — настоящий выпадающий
    /// список поверх остального контента (карточка со своей тенью), а не часть скролла.
    var tickerSearchRow: some View {
        HStack {
            Picker("", selection: $newTickerKind) {
                ForEach(AssetKind.allCases, id: \.self) { kind in
                    Text(kind.displayName(for: languageStore.current)).tag(kind)
                }
            }
            .labelsHidden()
            .frame(width: 90)
            .onChange(of: newTickerKind) { _ in scheduleSearch() }

            TextField(strings.tickerSearchPlaceholder, text: $newTickerSymbol)
                .textFieldStyle(.roundedBorder)
                .onChange(of: newTickerSymbol) { _ in scheduleSearch() }
        }
        .overlay(alignment: .topLeading) {
            if isDropdownVisible {
                searchDropdownCard
                    .offset(y: 30)
                    .zIndex(999)
            }
        }
    }

    var isDropdownVisible: Bool {
        !newTickerSymbol.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var searchDropdownCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isSearching {
                Text(strings.searching)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                searchResultsList
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.08)))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
    }

    @ViewBuilder
    var searchResultsList: some View {
        switch newTickerKind {
        case .crypto:
            if cryptoResults.isEmpty {
                Text(strings.nothingFound)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(cryptoResults.prefix(8), id: \.self) { symbol in
                    Button {
                        marketViewModel.addTicker(symbol: symbol, kind: .crypto)
                        resetSearch()
                    } label: {
                        HStack {
                            Text(symbol)
                            Spacer(minLength: 12)
                            Text(searchPrices[symbol].map(PriceFormatting.string(for:)) ?? "…")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                }
            }
        case .stock:
            if finnhubToken.isEmpty {
                Text(strings.saveFinnhubTokenFirst)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else if stockResults.isEmpty {
                Text(strings.nothingFound)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(stockResults.prefix(8)) { result in
                    Button {
                        marketViewModel.addTicker(symbol: result.symbol, kind: .stock)
                        resetSearch()
                    } label: {
                        HStack {
                            Text("\(result.symbol) — \(result.description)")
                                .lineLimit(1)
                            Spacer(minLength: 12)
                            Text(searchPrices[result.symbol].map(PriceFormatting.string(for:)) ?? "…")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .layoutPriority(1)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                }
            }
        }
    }

    func scheduleSearch() {
        searchTask?.cancel()
        priceTask?.cancel()
        let query = newTickerSymbol.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            isSearching = false
            cryptoResults = []
            stockResults = []
            searchPrices = [:]
            return
        }
        let kind = newTickerKind
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else {
                return
            }
            switch kind {
            case .crypto:
                let results = await cryptoDirectory.search(query: query)
                guard !Task.isCancelled else {
                    return
                }
                cryptoResults = results
                isSearching = false
                fetchCryptoPrices(for: results)
            case .stock:
                let results = await stockSearch.search(query: query)
                guard !Task.isCancelled else {
                    return
                }
                stockResults = results
                isSearching = false
                fetchStockPrices(for: results.map(\.symbol))
            }
        }
    }

    /// Один батч-запрос на все показанные монеты сразу — без спама по одному тикеру.
    func fetchCryptoPrices(for symbols: [String]) {
        let top = Array(symbols.prefix(8))
        guard !top.isEmpty else {
            return
        }
        priceTask = Task {
            let prices = await cryptoDirectory.prices(forBaseAssets: top)
            guard !Task.isCancelled else {
                return
            }
            searchPrices = prices
        }
    }

    /// У Finnhub нет батч-эндпоинта на бесплатном тарифе — котируем последовательно.
    func fetchStockPrices(for symbols: [String]) {
        let top = Array(symbols.prefix(8))
        guard !top.isEmpty else {
            return
        }
        priceTask = Task {
            var result: [String: Double] = [:]
            for symbol in top {
                guard !Task.isCancelled else {
                    return
                }
                if let price = await stockSearch.quote(symbol: symbol) {
                    result[symbol] = price
                }
            }
            guard !Task.isCancelled else {
                return
            }
            searchPrices = result
        }
    }

    func resetSearch() {
        searchTask?.cancel()
        priceTask?.cancel()
        newTickerSymbol = ""
        cryptoResults = []
        stockResults = []
        searchPrices = [:]
        isSearching = false
    }
}

// MARK: - Info

private extension SettingsView {
    var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(strings.infoTitle)
                .font(.headline)
            Text(strings.infoDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Text(strings.contactLabel + ":")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Link("iv.lugantsov@gmail.com", destination: URL(string: "mailto:iv.lugantsov@gmail.com")!)
                    .font(.subheadline)
            }
        }
    }
}
