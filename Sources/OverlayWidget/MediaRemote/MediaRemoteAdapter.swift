//
//  MediaRemoteAdapter.swift
//  OverlayWidget
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import Foundation

enum MediaRemoteCommand: Int {
    case play = 0
    case pause = 1
    case togglePlayPause = 2
    case nextTrack = 4
    case previousTrack = 5
}

protocol MediaRemoteAdapting {
    /// Полные снэпшоты now-playing состояния, живой поток пока приложение открыто.
    func nowPlayingUpdates() -> AsyncStream<NowPlayingInfo>
    /// `stream` шлёт данные только по новым уведомлениям — если музыка уже играла до
    /// запуска виджета, стрим может долго молчать. Разовый снимок текущего состояния
    /// нужен, чтобы не показывать пустую карточку, пока не случится следующее событие.
    func currentNowPlaying() async -> NowPlayingInfo?
    func send(_ command: MediaRemoteCommand) async
    func seek(toSeconds seconds: Double) async
    /// Из README адаптера: проверка через bundled test client, что обход MediaRemote-лока на этой macOS ещё жив.
    func healthCheck() async -> Bool
}

/// Гоняет системный /usr/bin/perl (у него есть entitlement на MediaRemote, у обычных
/// приложений — нет с macOS 15.4) поверх бандленного mediaremote-adapter.pl.
/// См. https://github.com/ungive/mediaremote-adapter
final class MediaRemoteAdapter: MediaRemoteAdapting {
    private enum Resource {
        static let script = "mediaremote-adapter"
        static let scriptExtension = "pl"
        static let framework = "MediaRemoteAdapter.framework"
        static let testClient = "MediaRemoteAdapterTestClient"
    }

    private let perlPath = "/usr/bin/perl"
    private let scriptURL: URL
    private let frameworkURL: URL
    private let testClientURL: URL

    private var streamProcess: Process?

    init?() {
        guard let scriptURL = Bundle.module.url(forResource: Resource.script, withExtension: Resource.scriptExtension),
              let frameworkURL = Bundle.module.url(forResource: Resource.framework, withExtension: nil),
              let testClientURL = Bundle.module.url(forResource: Resource.testClient, withExtension: nil) else {
            return nil
        }
        self.scriptURL = scriptURL
        self.frameworkURL = frameworkURL
        self.testClientURL = testClientURL
    }

    func nowPlayingUpdates() -> AsyncStream<NowPlayingInfo> {
        AsyncStream { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: perlPath)
            process.arguments = [
                scriptURL.path,
                frameworkURL.path,
                "stream",
                "--no-diff",
                "--micros",
                "--debounce=150"
            ]

            let pipe = Pipe()
            process.standardOutput = pipe

            // availableData отдаёт данные кусками произвольного размера — на треках с
            // крупной обложкой JSON-строка не влезает в один кусок. Резать по "\n" внутри
            // каждого чанка отдельно (как было раньше) рвёт такую строку пополам, обе
            // половинки не парсятся, и событие тихо теряется — виджет застревает на
            // предыдущем состоянии до следующего события. Буферизуем между вызовами.
            var buffer = Data()
            let newline = Data([0x0A])
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                guard !chunk.isEmpty else {
                    return
                }
                buffer.append(chunk)
                while let range = buffer.range(of: newline) {
                    let lineData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
                    buffer.removeSubrange(buffer.startIndex..<range.upperBound)
                    guard let text = String(data: lineData, encoding: .utf8),
                          let info = NowPlayingInfo.decodeStreamLine(text) else {
                        continue
                    }
                    continuation.yield(info)
                }
            }

            continuation.onTermination = { [weak process] _ in
                process?.terminate()
            }

            streamProcess = process
            try? process.run()
        }
    }

    func currentNowPlaying() async -> NowPlayingInfo? {
        guard let data = await runOneShotOutput(arguments: [scriptURL.path, frameworkURL.path, "get", "--micros"]) else {
            return nil
        }
        return try? JSONDecoder().decode(NowPlayingInfo.self, from: data)
    }

    func send(_ command: MediaRemoteCommand) async {
        await runOneShot(arguments: [scriptURL.path, frameworkURL.path, "send", String(command.rawValue)])
    }

    func seek(toSeconds seconds: Double) async {
        let microseconds = Int(seconds * 1_000_000)
        await runOneShot(arguments: [scriptURL.path, frameworkURL.path, "seek", String(microseconds)])
    }

    func healthCheck() async -> Bool {
        let exitCode = await runOneShotExitCode(
            arguments: [scriptURL.path, frameworkURL.path, testClientURL.path, "test"]
        )
        return exitCode == 0
    }
}

private extension MediaRemoteAdapter {
    func runOneShot(arguments: [String]) async {
        _ = await runOneShotExitCode(arguments: arguments)
    }

    func runOneShotOutput(arguments: [String]) async -> Data? {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: perlPath)
            process.arguments = arguments

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: data.isEmpty ? nil : data)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    func runOneShotExitCode(arguments: [String]) async -> Int32 {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: perlPath)
            process.arguments = arguments
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            process.terminationHandler = { finishedProcess in
                continuation.resume(returning: finishedProcess.terminationStatus)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: -1)
            }
        }
    }
}
