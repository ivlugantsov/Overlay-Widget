//
//  PetStatus.swift
//  OverlayWidget
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import Foundation

/// То, что сейчас делает Claude Code — пишется хуками в `~/.claude/pet_activity.json`.
struct PetActivity: Codable, Equatable {
    enum Event: String, Codable {
        case prompt
        case working
        case idle
    }

    let event: Event
    let message: String
    let ts: TimeInterval
}

/// Проценты использования лимитов — пишутся расширенным `statusline-command.sh`
/// в `~/.claude/pet_limits.json` при каждой отрисовке статус-строки.
struct PetLimits: Codable, Equatable {
    let fiveHourUsedPercent: Double
    let weekUsedPercent: Double
}

enum PetMood {
    case normal
    case tired
    case bloody

    init(hitPoints: Double) {
        switch hitPoints {
        case ..<20:
            self = .bloody
        case ..<50:
            self = .tired
        default:
            self = .normal
        }
    }
}
