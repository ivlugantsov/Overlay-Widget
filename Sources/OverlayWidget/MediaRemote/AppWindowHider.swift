//
//  AppWindowHider.swift
//  OverlayWidget
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import AppKit

/// hide() — то же самое, что Cmd+H: окно пропадает с экрана, приложение остаётся
/// активным в фоне (музыка не прерывается), без Accessibility permission.
///
/// Вызывать нужно ТОЛЬКО когда точно известно, что приложение уже полностью
/// загрузилось (например по факту начала воспроизведения из MediaRemote-стрима) —
/// более ранние сигналы (процесс запущен / окно появилось на экране) срабатывают
/// до того, как Electron-рендерер закончил инициализацию, из-за чего интерфейс
/// внутри приложения потом перестаёт реагировать на клики.
enum AppWindowHider {
    static func hide(bundleIdentifier: String) {
        NSWorkspace.shared.runningApplications
            .first { $0.bundleIdentifier == bundleIdentifier }?
            .hide()
    }
}
