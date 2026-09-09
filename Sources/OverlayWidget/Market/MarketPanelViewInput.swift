//
//  MarketPanelViewInput.swift
//  OverlayWidget
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import Foundation

/// Состояние панели котировок, отдельно от логики (MarketPanelViewModel).
final class MarketPanelViewInput: ObservableObject {
    @Published var isEnabled = false
    @Published var quotes: [MarketQuote] = []
}
