//
//  WidgetVisibilityStore.swift
//  OverlayWidget
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import Foundation

/// Плеер и панель котировок можно скрывать независимо друг от друга — не секрет,
/// поэтому UserDefaults, как и MarketSettingsStore.
final class WidgetVisibilityStore {
    private enum Keys {
        static let isPlayerVisible = "widget.isPlayerVisible"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Плеер по умолчанию виден (это исходное поведение до появления панели котировок) —
    /// поэтому дефолт true, а не bool(forKey:), который дал бы false для отсутствующего ключа.
    var isPlayerVisible: Bool {
        get { (defaults.object(forKey: Keys.isPlayerVisible) as? Bool) ?? true }
        set { defaults.set(newValue, forKey: Keys.isPlayerVisible) }
    }
}
