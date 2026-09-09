//
//  PetStatusStore.swift
//  OverlayWidget
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import Foundation

/// Следит за файлами, которые пишут хуки Claude Code, и публикует последнее состояние.
/// Поллинг раз в секунду — проще и надёжнее файловых уведомлений для atomic-replace записи (`> file`).
final class PetStatusStore: ObservableObject {
    @Published private(set) var activity: PetActivity?
    @Published private(set) var limits: PetLimits?

    private let activityURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/pet_activity.json")
    private let limitsURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/pet_limits.json")

    private var timer: Timer?
    private let decoder = JSONDecoder()

    func start() {
        reload()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.reload()
        }
    }

    private func reload() {
        if let data = try? Data(contentsOf: activityURL),
           let decoded = try? decoder.decode(PetActivity.self, from: data),
           decoded != activity {
            activity = decoded
        }

        if let data = try? Data(contentsOf: limitsURL),
           let decoded = try? decoder.decode(PetLimits.self, from: data),
           decoded != limits {
            limits = decoded
        }
    }
}
