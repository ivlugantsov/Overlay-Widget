//
//  AppLanguage.swift
//  OverlayWidget
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import Foundation

enum AppLanguage: String, CaseIterable {
    case ru
    case en

    /// Имя языка не переводится — всегда показывается на самом себе, как в System Settings.
    var displayName: String {
        switch self {
        case .ru: return "Русский"
        case .en: return "English"
        }
    }
}
