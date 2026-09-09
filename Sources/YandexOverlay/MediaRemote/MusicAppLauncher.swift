//
//  MusicAppLauncher.swift
//  YandexOverlay
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import AppKit

struct MusicApp: Identifiable, Equatable {
    let bundleIdentifier: String
    let displayName: String

    var id: String { bundleIdentifier }
}

/// Если ни один известный музыкальный плеер не запущен, системная MediaRemote-команда
/// play/pause сама открывает Apple Music (дефолтный приёмник у macOS) — вместо этого
/// показываем пользователю выбор, что запустить, из реально установленных приложений.
enum MusicAppLauncher {
    /// Лайк/дизлайк — через Yandex-специфичный API, поэтому bundle id нужен отдельно
    /// от общего списка (см. PlayerViewModel.apply(_:)).
    static let yandexMusicBundleIdentifier = "ru.yandex.desktop.music"

    private static let knownApps: [MusicApp] = [
        MusicApp(bundleIdentifier: yandexMusicBundleIdentifier, displayName: "Яндекс Музыка"),
        MusicApp(bundleIdentifier: "com.spotify.client", displayName: "Spotify"),
        MusicApp(bundleIdentifier: "com.apple.Music", displayName: "Music")
    ]

    static var installedApps: [MusicApp] {
        knownApps.filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.bundleIdentifier) != nil }
    }

    /// MediaRemote общесистемный — активной сессией может стать видео в браузере или
    /// подкаст-плеер. Виджет должен реагировать только на настоящие музыкальные приложения.
    static func isKnownMusicApp(bundleIdentifier: String) -> Bool {
        knownApps.contains { $0.bundleIdentifier == bundleIdentifier }
    }

    /// activates=false — приложение запускается/активируется, но не перехватывает фокус
    /// и не выпрыгивает поверх текущего окна пользователя.
    ///
    /// Автоплей через yandexmusic://play-vibe был убран: подтверждено (в том числе
    /// напрямую через `open`, вообще без виджета), что этот deep link ломает навигацию
    /// (поиск, "Моя Волна") внутри самого приложения до его перезапуска — баг Яндекс.Музыки,
    /// не наш. Взамен просто открываем приложение — играть пользователь запускает сам.
    static func launch(_ app: MusicApp) async {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) else {
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }
}
