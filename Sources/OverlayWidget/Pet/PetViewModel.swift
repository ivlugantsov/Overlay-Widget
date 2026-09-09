//
//  PetViewModel.swift
//  OverlayWidget
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import AppKit
import Combine
import SwiftUI

/// Питомец бродит по нижнему краю экрана, показывает пузырь с тем, что делает Claude,
/// и реагирует на новый запрос анимацией "хлыста", а на низкий остаток лимита — настроением.
final class PetViewModel: ObservableObject {
    static let panelSize = CGSize(width: 220, height: 132)
    static let creatureSize: CGFloat = 56

    private enum Constants {
        static let walkSpeed: CGFloat = 1.4
        static let roamTickInterval: TimeInterval = 1.0 / 30
        static let pauseChancePerTick: Double = 0.002
        static let pauseDuration: ClosedRange<TimeInterval> = 1.5...4
        static let speechDuration: TimeInterval = 4
        static let whipDuration: TimeInterval = 0.6
        static let bottomMargin: CGFloat = 4
    }

    @Published private(set) var windowOrigin: CGPoint
    @Published private(set) var facingRight = true
    @Published private(set) var isWalking = true
    @Published private(set) var mood: PetMood = .normal
    @Published private(set) var hitPoints: Double = 100
    @Published private(set) var speechText: String?
    @Published private(set) var isBeingWhipped = false
    @Published private(set) var isEnabled: Bool

    private let visibilityStore: WidgetVisibilityStore
    private var roamTimer: Timer?
    private var pauseUntil: Date?
    private var speechHideWorkItem: DispatchWorkItem?
    private var whipEndWorkItem: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()
    private var lastHandledActivityTimestamp: TimeInterval?

    init(visibilityStore: WidgetVisibilityStore) {
        self.visibilityStore = visibilityStore
        isEnabled = visibilityStore.isPetVisible
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        windowOrigin = CGPoint(
            x: screenFrame.midX,
            y: screenFrame.minY + Constants.bottomMargin
        )
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        visibilityStore.isPetVisible = enabled
    }

    func start(statusStore: PetStatusStore) {
        statusStore.start()

        statusStore.$activity
            .compactMap { $0 }
            .sink { [weak self] activity in
                self?.handle(activity: activity)
            }
            .store(in: &cancellables)

        statusStore.$limits
            .compactMap { $0 }
            .sink { [weak self] limits in
                self?.handle(limits: limits)
            }
            .store(in: &cancellables)

        roamTimer = Timer.scheduledTimer(withTimeInterval: Constants.roamTickInterval, repeats: true) { [weak self] _ in
            self?.tickRoaming()
        }
    }

    // MARK: - Activity → speech bubble + whip

    private func handle(activity: PetActivity) {
        guard activity.ts != lastHandledActivityTimestamp else {
            return
        }
        lastHandledActivityTimestamp = activity.ts

        switch activity.event {
        case .prompt:
            triggerWhip()
            showSpeech(activity.message.isEmpty ? "Новый запрос!" : activity.message)
        case .working:
            showSpeech(activity.message)
        case .idle:
            hideSpeech()
        }
    }

    private func showSpeech(_ text: String) {
        guard !text.isEmpty else {
            return
        }
        speechText = text
        speechHideWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.speechText = nil
        }
        speechHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.speechDuration, execute: workItem)
    }

    private func hideSpeech() {
        speechHideWorkItem?.cancel()
        speechText = nil
    }

    private func triggerWhip() {
        whipEndWorkItem?.cancel()
        isBeingWhipped = true
        let workItem = DispatchWorkItem { [weak self] in
            self?.isBeingWhipped = false
        }
        whipEndWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.whipDuration, execute: workItem)
    }

    // MARK: - Limits → mood

    private func handle(limits: PetLimits) {
        hitPoints = max(0, 100 - limits.fiveHourUsedPercent)
        mood = PetMood(hitPoints: hitPoints)
    }

    // MARK: - Roaming

    private func tickRoaming() {
        guard isEnabled else {
            return
        }

        if let pauseUntil {
            if Date() < pauseUntil {
                isWalking = false
                return
            }
            self.pauseUntil = nil
        }

        guard mood != .bloody else {
            // При критически низком HP питомец лежит без сил, не бродит.
            isWalking = false
            return
        }

        isWalking = true

        if Double.random(in: 0...1) < Constants.pauseChancePerTick {
            pauseUntil = Date().addingTimeInterval(.random(in: Constants.pauseDuration))
            return
        }

        let speed = mood == .tired ? Constants.walkSpeed * 0.5 : Constants.walkSpeed
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let minX = screenFrame.minX
        let maxX = screenFrame.maxX - PetViewModel.panelSize.width

        var newX = windowOrigin.x + (facingRight ? speed : -speed)
        if newX >= maxX {
            newX = maxX
            facingRight = false
        } else if newX <= minX {
            newX = minX
            facingRight = true
        }

        windowOrigin = CGPoint(x: newX, y: screenFrame.minY + Constants.bottomMargin)
    }
}
