//
//  YandexOverlayApp.swift
//  YandexOverlay
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: OverlayPanel?
    private var viewModel: PlayerViewModel?
    private var marketViewModel: MarketPanelViewModel?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var settingsMenuItem: NSMenuItem?
    private var quitMenuItem: NSMenuItem?
    private var languageCancellable: AnyCancellable?
    private let yandexTokenStore = KeychainService(service: "com.ivlugantsov.YandexOverlay.yandexToken")
    private let finnhubTokenStore = KeychainService(service: "com.ivlugantsov.YandexOverlay.finnhubToken")
    private lazy var stockFeed = FinnhubStockFeed(tokenStore: finnhubTokenStore)
    private let cryptoDirectory = BinanceSymbolDirectory()
    private let visibilityStore = WidgetVisibilityStore()
    private let languageStore = LanguageStore()
    private let launchAtLoginController = LaunchAtLoginController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Без Dock-иконки — это фоновый оверлей, не обычное приложение.
        NSApp.setActivationPolicy(.accessory)

        // Без Edit-меню с пунктом Paste (даже скрытого) Cmd+V не маршрутизируется в
        // текстовые поля окна настроек — стандартное поведение AppKit для приложений
        // без mainMenu, не баг конкретного поля.
        setupMainMenu()
        setupStatusItem()

        // AppKit-меню не SwiftUI — на смену языка не перерисовываются сами,
        // подписываемся и переприсваиваем title вручную.
        languageCancellable = languageStore.$current.sink { [weak self] language in
            self?.applyMenuLocalization(language)
        }

        guard let mediaRemote = MediaRemoteAdapter() else {
            preconditionFailure("Не найдены бандленные ресурсы mediaremote-adapter — проверь Package.swift resources")
        }

        let yandexClient = YandexMusicClient(tokenStore: yandexTokenStore)
        let viewModel = PlayerViewModel(mediaRemote: mediaRemote, yandexClient: yandexClient, visibilityStore: visibilityStore)
        self.viewModel = viewModel
        viewModel.start()

        let marketViewModel = MarketPanelViewModel(
            settingsStore: MarketSettingsStore(),
            cryptoFeed: BinanceCryptoFeed(),
            stockFeed: stockFeed
        )
        self.marketViewModel = marketViewModel
        marketViewModel.start()

        let rootView = OverlayRootView(playerViewModel: viewModel, marketViewModel: marketViewModel) { [weak self] size in
            self?.panel?.resize(toContentSize: size)
        }
        .environmentObject(languageStore)
        let panel = OverlayPanel(rootView: rootView)
        panel.setFrameTopLeftPoint(NSPoint(x: 40, y: NSScreen.main?.frame.height ?? 800 - 40))
        panel.orderFrontRegardless()
        self.panel = panel
    }
}

// MARK: - Menu bar

private extension AppDelegate {
    func setupMainMenu() {
        let mainMenu = NSMenu()

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: languageStore.current.strings.undo, action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: languageStore.current.strings.redo, action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: languageStore.current.strings.cut, action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: languageStore.current.strings.copy, action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: languageStore.current.strings.paste, action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(
            withTitle: languageStore.current.strings.selectAll,
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a"
        )
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        // rectangle.on.rectangle — буквально "оверлей", нейтрально к музыке/крипте,
        // как и сама идея виджета: одно плавающее окно поверх другого.
        item.button?.image = NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: "Overlay Widget")

        let menu = NSMenu()
        let settingsMenuItem = menu.addItem(
            withTitle: languageStore.current.strings.settingsMenuItem,
            action: #selector(didTapSettings),
            keyEquivalent: ","
        )
        settingsMenuItem.target = self
        self.settingsMenuItem = settingsMenuItem

        menu.addItem(.separator())

        let quitMenuItem = menu.addItem(
            withTitle: languageStore.current.strings.quitMenuItem,
            action: #selector(didTapQuit),
            keyEquivalent: "q"
        )
        quitMenuItem.target = self
        self.quitMenuItem = quitMenuItem

        item.menu = menu
        statusItem = item
    }

    func applyMenuLocalization(_ language: AppLanguage) {
        settingsMenuItem?.title = language.strings.settingsMenuItem
        quitMenuItem?.title = language.strings.quitMenuItem
        settingsWindow?.title = language.strings.settingsWindowTitle
    }

    @objc func didTapSettings() {
        if settingsWindow == nil, let marketViewModel, let viewModel {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 340, height: 560),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = languageStore.current.strings.settingsWindowTitle
            window.contentView = NSHostingView(rootView: SettingsView(
                yandexTokenStore: yandexTokenStore,
                finnhubTokenStore: finnhubTokenStore,
                playerViewModel: viewModel,
                marketViewModel: marketViewModel,
                cryptoDirectory: cryptoDirectory,
                stockSearch: stockFeed,
                launchAtLoginController: launchAtLoginController
            ).environmentObject(languageStore))
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        settingsWindow?.center()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc func didTapQuit() {
        NSApp.terminate(nil)
    }
}

@main
enum YandexOverlayApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
