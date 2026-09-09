//
//  PlayerViewModel.swift
//  OverlayWidget
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import AppKit

@MainActor
final class PlayerViewModel {
    let viewInput = PlayerViewInput()

    private let mediaRemote: MediaRemoteAdapting
    private let yandexClient: YandexMusicClientProtocol
    private let visibilityStore: WidgetVisibilityStore
    private let audioRouteObserver = AudioRouteObserver()

    private var updatesTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?
    private var likeStatusTask: Task<Void, Never>?

    /// ID трека в Yandex Music для текущего title/artist — нужен только для лайка/дизлайка,
    /// resolve'ится поиском отдельно от MediaRemote-потока (см. YandexMusicClient).
    private var resolvedTrackID: String?
    private var lastResolvedKey: String?
    /// bundleIdentifier последнего реального now-playing события. macOS роутит системную
    /// play/pause-команду по АКТИВНОЙ MediaRemote-сессии, не по факту запуска процесса —
    /// если у известного плеера сессии ещё нет (открыт, но ничего не запускали), команда
    /// всё равно уйдёт куда-то ещё (обычно в Apple Music).
    private var lastBundleIdentifier: String?
    /// Установлен после выбора приложения из списка — как только у него появится
    /// СВОЯ now-playing-сессия (даже на паузе, если оно само подхватило последний
    /// трек при запуске), сразу шлём play, не дожидаясь ручного тапа внутри приложения.
    private var pendingAutoPlayBundleIdentifier: String?
    /// true, пока идёт запуск выбранного приложения и ожидание первого воспроизведения —
    /// на это время список приложений по тапу на транспортные кнопки не показываем повторно.
    private var isLaunchInProgress = false
    private var terminationObserver: NSObjectProtocol?
    /// Пока не истёк — входящие elapsedTime из стрима игнорируем. Сразу после seek
    /// сам плеер ещё какое-то время шлёт старую позицию, и бегунок дёргается назад
    /// перед тем как долетит реальное обновление — ждём, пока оно точно устаканится.
    private var seekSuppressionDeadline: Date?

    init(mediaRemote: MediaRemoteAdapting, yandexClient: YandexMusicClientProtocol, visibilityStore: WidgetVisibilityStore) {
        self.mediaRemote = mediaRemote
        self.yandexClient = yandexClient
        self.visibilityStore = visibilityStore
        viewInput.isVisible = visibilityStore.isPlayerVisible
    }

    func setVisible(_ visible: Bool) {
        viewInput.isVisible = visible
        visibilityStore.isPlayerVisible = visible
    }

    func start() {
        Task { [weak self] in
            guard let self else {
                return
            }
            viewInput.isControlsAvailable = await mediaRemote.healthCheck()
        }

        Task { [weak self] in
            guard let self, let info = await mediaRemote.currentNowPlaying() else {
                return
            }
            apply(info)
        }

        updatesTask = Task { [weak self] in
            guard let self else {
                return
            }
            for await info in mediaRemote.nowPlayingUpdates() {
                apply(info)
            }
        }

        startLocalTicking()

        audioRouteObserver.start { [weak self] in
            Task { @MainActor in
                self?.viewInput.isPlaying = false
            }
        }

        terminationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let bundleIdentifier = (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?
                .bundleIdentifier else {
                return
            }
            Task { @MainActor in
                guard bundleIdentifier == self?.lastBundleIdentifier else {
                    return
                }
                self?.resetNowPlayingState()
            }
        }
    }

    func stop() {
        updatesTask?.cancel()
        tickTask?.cancel()
        if let terminationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(terminationObserver)
        }
    }
}

// MARK: - User actions

extension PlayerViewModel {
    func didTapPlayPause() {
        guardedSend(.togglePlayPause)
    }

    func didTapNext() {
        guardedSend(.nextTrack)
    }

    func didTapPrevious() {
        guardedSend(.previousTrack)
    }

    func didSelectAppToLaunch(_ app: MusicApp) {
        viewInput.appsToLaunch = nil
        pendingAutoPlayBundleIdentifier = app.bundleIdentifier
        isLaunchInProgress = true

        Task { [weak self] in
            await MusicAppLauncher.launch(app)
            await self?.waitUntilPlayingThenHideWindow(app)
            self?.isLaunchInProgress = false
        }
    }

    /// В отличие от launch()/guardedSend — тут явно хотим активировать и показать
    /// приложение (это же его окно скрыто hide()'ом после автозапуска), а не просто
    /// послать команду в фон.
    func didTapTrackInfo() {
        guard let lastBundleIdentifier,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: lastBundleIdentifier) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func didSeek(toSeconds seconds: Double) {
        viewInput.elapsedSeconds = seconds
        seekSuppressionDeadline = Date().addingTimeInterval(1)
        Task { await mediaRemote.seek(toSeconds: seconds) }
    }

    func didTapLike() {
        guard let trackID = resolvedTrackID else {
            return
        }
        let isLiked = !viewInput.isLiked
        viewInput.isLiked = isLiked
        Task {
            if isLiked {
                await yandexClient.like(trackID: trackID)
            } else {
                await yandexClient.unlike(trackID: trackID)
            }
        }
    }

}

// MARK: - Private

private extension PlayerViewModel {
    /// MediaRemote общесистемный — активной сессией может быть что угодно (браузер с
    /// видео, подкаст-плеер), не только наши "известные" музыкальные приложения. Список
    /// для запуска показываем только когда сессии вообще нет — иначе команда просто уходит
    /// в текущую активную сессию, кто бы её ни держал.
    func guardedSend(_ command: MediaRemoteCommand) {
        guard lastBundleIdentifier != nil else {
            // Пока сами уже пытаемся запустить приложение и дождаться первого трека —
            // не перебиваем это повторным показом списка на каждый тап по кнопкам.
            guard !isLaunchInProgress else {
                return
            }
            viewInput.appsToLaunch = MusicAppLauncher.installedApps
            return
        }
        Task { await mediaRemote.send(command) }
    }

    /// Прячем окно только после подтверждённого начала воспроизведения — более ранние
    /// сигналы (процесс запущен, окно на экране) срабатывают до конца загрузки Electron-
    /// рендерера. Повторной отправки deep link'а здесь больше нет: подтверждено дважды —
    /// любое повторное автоматическое действие с приложением, пока пользователь мог
    /// начать в нём кликать, ломает интерактивность (клики визуально анимируются, но не
    /// срабатывают). Лучше редкий случай "не заиграло с первого раза — нажми play ещё раз",
    /// чем сломанные кнопки внутри Яндекс.Музыки.
    func waitUntilPlayingThenHideWindow(_ app: MusicApp) async {
        for _ in 0..<75 {
            if lastBundleIdentifier == app.bundleIdentifier, viewInput.isPlaying {
                AppWindowHider.hide(bundleIdentifier: app.bundleIdentifier)
                return
            }
            try? await Task.sleep(nanoseconds: 400_000_000)
        }
        // Не заиграло за ~30 секунд — оставляем окно как есть, пусть пользователь разберётся сам.
    }

    /// Приложение закрыли — сбрасываем всё, иначе виджет продолжает показывать
    /// последнюю обложку/трек как будто что-то ещё играет.
    func resetNowPlayingState() {
        lastBundleIdentifier = nil
        resolvedTrackID = nil
        lastResolvedKey = nil
        viewInput.title = ""
        viewInput.artist = ""
        viewInput.artwork = nil
        viewInput.isPlaying = false
        viewInput.elapsedSeconds = 0
        viewInput.durationSeconds = 0
        viewInput.isLiked = false
        viewInput.isLikeAvailable = false
    }

    func apply(_ info: NowPlayingInfo) {
        // Между треками адаптер иногда шлёт полностью пустой payload как промежуточное
        // состояние — если его не игнорировать, виджет на долю секунды показывает
        // "ничего не играет" и сбрасывает обложку/прогресс/лайк, хотя реальное обновление
        // о новом треке просто ещё не долетело. Настоящий "ничего не играет" (приложение
        // закрыли) обрабатывается отдельно через resetNowPlayingState().
        guard info.bundleIdentifier != nil || info.title != nil else {
            return
        }

        // Не музыкальное приложение (видео в браузере, подкаст-плеер и т.п.) — игнорируем
        // целиком, виджет остаётся на последнем реальном треке, а не переключается на что попало.
        if let bundleIdentifier = info.bundleIdentifier,
           !MusicAppLauncher.isKnownMusicApp(bundleIdentifier: bundleIdentifier) {
            return
        }

        lastBundleIdentifier = info.bundleIdentifier
        // @Published шлёт objectWillChange на любое присваивание, даже с тем же значением —
        // событий из стрима много и большинство ничего реально не меняют, лишний
        // objectWillChange = лишняя перерисовка всей карточки без единого видимого изменения.
        if viewInput.appsToLaunch != nil {
            viewInput.appsToLaunch = nil
        }
        let isLikeAvailable = info.bundleIdentifier == MusicAppLauncher.yandexMusicBundleIdentifier
        if viewInput.isLikeAvailable != isLikeAvailable {
            viewInput.isLikeAvailable = isLikeAvailable
        }

        if pendingAutoPlayBundleIdentifier != nil, info.bundleIdentifier == pendingAutoPlayBundleIdentifier {
            pendingAutoPlayBundleIdentifier = nil
            Task { await mediaRemote.send(.play) }
        }

        // Реальная смена трека всегда важнее недавнего seek'а — иначе suppression-окно
        // держит elapsed от старого трека ещё секунду, а duration уже от нового,
        // и прогресс-бар на секунду показывает мусор (перекос elapsed/duration).
        let isNewTrack = (info.title ?? "") != viewInput.title || (info.artist ?? "") != viewInput.artist
        if isNewTrack {
            seekSuppressionDeadline = nil
            viewInput.artwork = nil
            viewInput.title = info.title ?? ""
            viewInput.artist = info.artist ?? ""
        }

        let isPlaying = info.playing ?? false
        if viewInput.isPlaying != isPlaying {
            viewInput.isPlaying = isPlaying
        }
        let isSuppressingElapsed = seekSuppressionDeadline.map { Date() < $0 } ?? false
        if !isSuppressingElapsed {
            let elapsedSeconds = (info.elapsedTimeMicros ?? 0) / 1_000_000
            if viewInput.elapsedSeconds != elapsedSeconds {
                viewInput.elapsedSeconds = elapsedSeconds
            }
        }
        let durationSeconds = (info.durationMicros ?? 0) / 1_000_000
        if viewInput.durationSeconds != durationSeconds {
            viewInput.durationSeconds = durationSeconds
        }

        // Пустая строка (не nil) на "тихих" обновлениях (например сразу после паузы) —
        // не повод стирать уже показанную обложку, поэтому не трогаем artwork при неудаче.
        if let artworkData = info.artworkData, !artworkData.isEmpty,
           let data = Data(base64Encoded: artworkData), let image = NSImage(data: data) {
            viewInput.artwork = image
        }

        if isNewTrack, viewInput.artwork == nil {
            refreshArtworkIfStillMissing(expectedTitle: viewInput.title, expectedArtist: viewInput.artist)
        }

        resolveTrackIDIfNeeded(title: info.title, artist: info.artist)
    }

    /// На части треков обложка не долетает в самом событии смены трека (в самом
    /// Яндекс.Музыке она при этом есть — просто задержка публикации в MediaRemote).
    /// Через паузу берём полный снимок ещё раз и подставляем, если он всё же появился.
    func refreshArtworkIfStillMissing(expectedTitle: String, expectedArtist: String) {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard let self, viewInput.artwork == nil,
                  viewInput.title == expectedTitle, viewInput.artist == expectedArtist,
                  let info = await mediaRemote.currentNowPlaying(),
                  let artworkData = info.artworkData, !artworkData.isEmpty,
                  let data = Data(base64Encoded: artworkData), let image = NSImage(data: data) else {
                return
            }
            viewInput.artwork = image
        }
    }

    /// Тикаем прогресс локально между событиями стрима (elapsedTime приходит не непрерывно),
    /// ресинк на каждое реальное событие уже произошёл в apply(_:) выше.
    func startLocalTicking() {
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard let self else {
                    return
                }
                guard viewInput.isPlaying, viewInput.durationSeconds > 0 else {
                    continue
                }
                viewInput.elapsedSeconds = min(viewInput.elapsedSeconds + 0.5, viewInput.durationSeconds)
            }
        }
    }

    func resolveTrackIDIfNeeded(title: String?, artist: String?) {
        guard let title, let artist, !title.isEmpty, !artist.isEmpty else {
            return
        }

        let key = artist + "—" + title
        guard key != lastResolvedKey else {
            return
        }
        lastResolvedKey = key
        resolvedTrackID = nil
        viewInput.isLiked = false

        likeStatusTask?.cancel()
        likeStatusTask = Task { [weak self] in
            guard let self else {
                return
            }
            guard let resolved = await yandexClient.resolveTrack(title: title, artist: artist) else {
                return
            }
            guard !Task.isCancelled, key == lastResolvedKey else {
                return
            }
            resolvedTrackID = resolved.id
            viewInput.isLiked = await yandexClient.likeStatus(trackID: resolved.id) ?? false

            // Обложка из MediaRemote уже могла показаться — здесь просто апгрейдим её на
            // более качественную версию из поиска, как только она станет известна.
            guard let coverURL = resolved.coverURL,
                  let data = await yandexClient.fetchArtwork(url: coverURL),
                  !Task.isCancelled, key == lastResolvedKey,
                  let image = NSImage(data: data) else {
                return
            }
            viewInput.artwork = image
        }
    }
}
