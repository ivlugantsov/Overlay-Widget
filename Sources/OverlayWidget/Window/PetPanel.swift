//
//  PetPanel.swift
//  OverlayWidget
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import AppKit
import Combine
import SwiftUI

/// Отдельная плавающая панель для питомца — бродит по экрану сама, без участия пользователя.
/// Не перехватывает клики (`ignoresMouseEvents`), это чисто декоративный элемент.
final class PetPanel: NSPanel {
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: PetViewModel) {
        let size = PetViewModel.panelSize
        super.init(
            contentRect: NSRect(origin: viewModel.windowOrigin, size: size),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true

        contentView = NSHostingView(rootView: PetView(viewModel: viewModel))

        viewModel.$windowOrigin
            .sink { [weak self] origin in
                self?.setFrameOrigin(origin)
            }
            .store(in: &cancellables)

        viewModel.$isEnabled
            .sink { [weak self] isEnabled in
                if isEnabled {
                    self?.orderFrontRegardless()
                } else {
                    self?.orderOut(nil)
                }
            }
            .store(in: &cancellables)
    }
}
