//
//  NowPlayingInfo.swift
//  OverlayWidget
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import Foundation

/// Снапшот состояния плеера от mediaremote-adapter. Поля опциональны, т.к. не все
/// плееры/треки заполняют весь набор (например artworkData может прийти позже отдельным событием).
struct NowPlayingInfo: Codable, Equatable {
    let bundleIdentifier: String?
    let playing: Bool?
    let title: String?
    let artist: String?
    let album: String?
    /// Микросекунды — адаптер запущен с флагом --micros. Имена полей совпадают с
    /// реальным JSON адаптера (durationMicros/elapsedTimeMicros), не с именами из README.
    let durationMicros: Double?
    let elapsedTimeMicros: Double?
    let artworkData: String?
    let artworkMimeType: String?
    let isLiked: Bool?
    let isBanned: Bool?
}

/// Обёртка вокруг каждой строки stdout в режиме `stream`.
private struct StreamEvent: Codable {
    let type: String
    let payload: NowPlayingInfo?
}

extension NowPlayingInfo {
    /// `stream --no-diff` шлёт полный снэпшот в каждой строке, поэтому парсим построчно без мёржа состояния.
    static func decodeStreamLine(_ line: String) -> NowPlayingInfo? {
        guard let data = line.data(using: .utf8),
              let event = try? JSONDecoder().decode(StreamEvent.self, from: data) else {
            return nil
        }
        return event.payload
    }
}
