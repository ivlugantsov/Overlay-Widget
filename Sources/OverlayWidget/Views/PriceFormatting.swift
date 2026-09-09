//
//  PriceFormatting.swift
//  OverlayWidget
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import Foundation

/// Общий формат отображения цены — с разделителем разрядов, чтобы "49000" не сливалось
/// в одну нечитаемую строку. Используется и в панели котировок, и в поиске тикеров.
enum PriceFormatting {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = " "
        return formatter
    }()

    static func string(for price: Double) -> String {
        formatter.maximumFractionDigits = price >= 1000 ? 0 : 2
        formatter.minimumFractionDigits = price >= 1000 ? 0 : 2
        let number = formatter.string(from: NSNumber(value: price)) ?? String(format: "%.2f", price)
        return "\(number)$"
    }
}
