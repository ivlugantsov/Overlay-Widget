//
//  PlayerViewInput.swift
//  OverlayWidget
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import AppKit

/// Состояние карточки плеера, отдельно от логики (PlayerViewModel).
final class PlayerViewInput: ObservableObject {
    @Published var title = ""
    @Published var artist = ""
    @Published var artwork: NSImage?
    @Published var isPlaying = false
    @Published var elapsedSeconds: Double = 0
    @Published var durationSeconds: Double = 0
    @Published var isLiked = false
    /// Лайк — Yandex-специфичный API, для Spotify/Apple Music смысла не имеет.
    @Published var isLikeAvailable = false
    /// false, если health-check адаптера провалился (например Apple прикрыла обход) —
    /// показываем нейтральное состояние вместо краша/пустых контролов.
    @Published var isControlsAvailable = true
    /// Не nil, когда ни один известный плеер не запущен — вместо транспортных кнопок
    /// показываем список того, что можно запустить (см. MusicAppLauncher).
    @Published var appsToLaunch: [MusicApp]?
    /// Можно скрыть карточку плеера отдельно от панели котировок (см. Настройки).
    @Published var isVisible = true
}
