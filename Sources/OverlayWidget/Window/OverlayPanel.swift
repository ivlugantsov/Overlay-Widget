//
//  OverlayPanel.swift
//  OverlayWidget
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import AppKit
import SwiftUI

/// Плавающая панель поверх всех окон и Spaces, включая full-screen приложения.
/// .nonactivatingPanel — тап по карточке не переключает фокус/активацию на это приложение.
final class OverlayPanel: NSPanel {
    init(rootView: some View) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 140),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )

        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        contentView = NSHostingView(rootView: rootView)
    }

    /// Карточка меняет высоту (разворот обложки) — держим левый верхний угол на месте
    /// и растягиваем/сжимаем окно вниз, а не от центра.
    func resize(toContentSize size: CGSize) {
        guard size.width > 0, size.height > 0 else {
            return
        }
        let newFrame = frameRect(forContentRect: NSRect(origin: .zero, size: size))
        var updatedFrame = frame
        let deltaHeight = newFrame.height - updatedFrame.height
        // Суб-пиксельные колебания layout (например разная высота глифа play/pause)
        // не должны запускать анимацию окна — иначе виджет заметно дёргается на каждый тап.
        guard abs(deltaHeight) >= 1 || abs(newFrame.width - updatedFrame.width) >= 1 else {
            return
        }
        updatedFrame.size = newFrame.size
        updatedFrame.origin.y -= deltaHeight
        setFrame(updatedFrame, display: true, animate: true)
    }
}
