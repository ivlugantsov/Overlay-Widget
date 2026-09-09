//
//  WidgetStyle.swift
//  YandexOverlay
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import Foundation

/// Общие константы стиля карточек оверлея — чтобы панель котировок не выбивалась
/// визуально из карточки плеера (одна ширина, скругление, паддинг, межблочный отступ).
enum WidgetStyle {
    static let cardWidth: CGFloat = 300
    static let cardPadding: CGFloat = 14
    static let cornerRadius: CGFloat = 20
    static let stackSpacing: CGFloat = 10
}
