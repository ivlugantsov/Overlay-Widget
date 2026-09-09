//
//  BinanceCryptoFeed.swift
//  OverlayWidget
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import Foundation

protocol CryptoFeeding {
    /// (symbol: "btcusdt", price: 49123.45) — сырые события с сокета, без фильтрации.
    func priceUpdates() -> AsyncStream<(symbol: String, price: Double)>
    func subscribe(streamSymbols: [String])
    func unsubscribe(streamSymbols: [String])
}

/// Публичный WebSocket Binance — без ключей и авторизации. Комбинированный endpoint
/// `/ws` + SUBSCRIBE/UNSUBSCRIBE позволяет менять список тикеров на лету, без переподключения.
final class BinanceCryptoFeed: CryptoFeeding {
    private enum Constants {
        static let url = URL(string: "wss://stream.binance.com:9443/ws")!
        static let reconnectDelayNanos: UInt64 = 3_000_000_000
    }

    private var webSocketTask: URLSessionWebSocketTask?
    private var continuation: AsyncStream<(symbol: String, price: Double)>.Continuation?
    private var activeStreamSymbols: Set<String> = []
    private var nextRequestID = 1

    func priceUpdates() -> AsyncStream<(symbol: String, price: Double)> {
        AsyncStream { [weak self] continuation in
            self?.continuation = continuation
            self?.connect()
        }
    }

    func subscribe(streamSymbols: [String]) {
        activeStreamSymbols.formUnion(streamSymbols)
        send(method: "SUBSCRIBE", params: streamSymbols)
    }

    func unsubscribe(streamSymbols: [String]) {
        activeStreamSymbols.subtract(streamSymbols)
        send(method: "UNSUBSCRIBE", params: streamSymbols)
    }
}

private extension BinanceCryptoFeed {
    func connect() {
        let task = URLSession.shared.webSocketTask(with: Constants.url)
        webSocketTask = task
        task.resume()
        listen()

        if !activeStreamSymbols.isEmpty {
            send(method: "SUBSCRIBE", params: Array(activeStreamSymbols))
        }
    }

    func listen() {
        webSocketTask?.receive { [weak self] result in
            guard let self else {
                return
            }
            switch result {
            case .failure:
                reconnectAfterDelay()
            case .success(let message):
                handle(message)
                listen()
            }
        }
    }

    func handle(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let symbol = json["s"] as? String,
              let priceString = json["p"] as? String,
              let price = Double(priceString) else {
            return
        }
        continuation?.yield((symbol: symbol.lowercased(), price: price))
    }

    func send(method: String, params: [String]) {
        guard !params.isEmpty else {
            return
        }
        let id = nextRequestID
        nextRequestID += 1
        let payload: [String: Any] = ["method": method, "params": params, "id": id]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else {
            return
        }
        webSocketTask?.send(.string(text)) { _ in }
    }

    func reconnectAfterDelay() {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: Constants.reconnectDelayNanos)
            self?.connect()
        }
    }
}
