//
//  AudioRouteObserver.swift
//  YandexOverlay
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import CoreAudio
import Foundation

/// Смена дефолтного аудиовыхода (например отключение наушников) обычно останавливает
/// звук у активного плеера, но Electron-приложения (Яндекс.Музыка) не всегда переотправляют
/// актуальный playbackState в MediaRemote при этом — стрим может застрять в "играет".
final class AudioRouteObserver {
    private var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    func start(onChange: @escaping () -> Void) {
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main) { _, _ in
            onChange()
        }
    }
}
