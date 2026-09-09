//
//  MarketPanelView.swift
//  OverlayWidget
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import SwiftUI

/// Тот же визуальный язык, что у карточки плеера (WidgetStyle) — отдельная карточка,
/// не разрывающая общий стиль оверлея.
struct MarketPanelView: View {
    @ObservedObject private var viewInput: MarketPanelViewInput
    @EnvironmentObject private var languageStore: LanguageStore

    init(viewModel: MarketPanelViewModel) {
        viewInput = viewModel.viewInput
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MarketQuoteRow.Constants.rowSpacing) {
            if viewInput.quotes.isEmpty {
                Text(languageStore.current.strings.quotesEmpty)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                // .equatable() — апдейт цены одного тикера не должен пересчитывать и
                // перерисовывать строки остальных, у которых MarketQuote не изменился.
                ForEach(viewInput.quotes) { quote in
                    MarketQuoteRow(quote: quote).equatable()
                }
            }
        }
        .padding(WidgetStyle.cardPadding)
        .frame(width: WidgetStyle.cardWidth, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: WidgetStyle.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: WidgetStyle.cornerRadius)
                .strokeBorder(Color.white.opacity(0.08))
        )
    }
}

/// Отдельный Equatable-тип на строку — необходимое условие для .equatable() выше:
/// SwiftUI сравнивает старое/новое значение и пропускает body, если MarketQuote не изменился.
private struct MarketQuoteRow: View, Equatable {
    enum Constants {
        static let rowFontSize: CGFloat = 13
        static let rowSpacing: CGFloat = 6
        static let iconSize: CGFloat = 18
    }

    let quote: MarketQuote

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.quote == rhs.quote
    }

    var body: some View {
        HStack(spacing: 8) {
            icon
            Text(quote.ticker.symbol)
                .font(.system(size: Constants.rowFontSize, weight: .semibold))
            Spacer(minLength: 12)
            Text(priceText)
                .font(.system(size: Constants.rowFontSize, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

private extension MarketQuoteRow {
    @ViewBuilder
    var icon: some View {
        let url = quote.ticker.kind == .crypto ? quote.ticker.cryptoIconURL : quote.stockLogoURL
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fit)
                    } else {
                        placeholderIcon
                    }
                }
            } else {
                placeholderIcon
            }
        }
        .frame(width: Constants.iconSize, height: Constants.iconSize)
        .clipShape(Circle())
    }

    var placeholderIcon: some View {
        Circle().fill(Color.white.opacity(0.12))
    }

    var priceText: String {
        guard let price = quote.price else {
            return "…"
        }
        return PriceFormatting.string(for: price)
    }
}
