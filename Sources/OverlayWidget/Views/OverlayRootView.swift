//
//  OverlayRootView.swift
//  OverlayWidget
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import SwiftUI

private struct RootSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

/// Карточка плеера + опциональная (по настройке) карточка котировок — раздельные
/// виджеты со своим отступом между собой, как соседние виджеты на локскрине iPhone.
struct OverlayRootView: View {
    @ObservedObject private var playerViewInput: PlayerViewInput
    @ObservedObject private var marketViewInput: MarketPanelViewInput
    private let playerViewModel: PlayerViewModel
    private let marketViewModel: MarketPanelViewModel
    private let onSizeChange: ((CGSize) -> Void)?

    init(
        playerViewModel: PlayerViewModel,
        marketViewModel: MarketPanelViewModel,
        onSizeChange: ((CGSize) -> Void)? = nil
    ) {
        self.playerViewModel = playerViewModel
        self.marketViewModel = marketViewModel
        self.onSizeChange = onSizeChange
        playerViewInput = playerViewModel.viewInput
        marketViewInput = marketViewModel.viewInput
    }

    var body: some View {
        VStack(spacing: WidgetStyle.stackSpacing) {
            if playerViewInput.isVisible {
                PlayerCardView(viewModel: playerViewModel)
            }
            if marketViewInput.isEnabled {
                MarketPanelView(viewModel: marketViewModel)
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: RootSizeKey.self, value: proxy.size)
            }
        )
        .onPreferenceChange(RootSizeKey.self) { size in
            onSizeChange?(size)
        }
    }
}
