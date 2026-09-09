//
//  YandexMusicClient.swift
//  YandexOverlay
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import Foundation

struct ResolvedTrack {
    let id: String
    /// Обложка из поиска Yandex — крупнее и не пережата по сравнению с тем, что отдаёт
    /// MediaRemote для системных виджетов.
    let coverURL: URL?
}

protocol YandexMusicClientProtocol {
    /// MediaRemote отдаёт только generic title/artist, не ID трека Yandex — сопоставляем поиском.
    func resolveTrack(title: String, artist: String) async -> ResolvedTrack?
    func likeStatus(trackID: String) async -> Bool?
    func like(trackID: String) async
    func unlike(trackID: String) async
    func fetchArtwork(url: URL) async -> Data?
}

/// Неофициальный API Yandex Music (тот же, на котором построена MarshalX/yandex-music-api).
/// Формат параметров сверен живьём через curl с реальным токеном: /likes/tracks/add ждёт
/// "trackId" (не "track-ids"), /likes/tracks/remove — "trackIds"; ответ /likes/tracks —
/// вложенный result.library.tracks, не плоский массив.
final class YandexMusicClient: YandexMusicClientProtocol {
    private enum Constants {
        static let baseURL = URL(string: "https://api.music.yandex.net")!
    }

    private let tokenStore: TokenStoring
    private let session: URLSession
    private var cachedAccountID: String?

    init(tokenStore: TokenStoring, session: URLSession = .shared) {
        self.tokenStore = tokenStore
        self.session = session
    }

    func resolveTrack(title: String, artist: String) async -> ResolvedTrack? {
        guard let response = await get(path: "/search", query: [
            "text": "\(artist) \(title)",
            "type": "track",
            "page": "0"
        ]) else {
            return nil
        }

        return firstTrack(fromSearchResponse: response)
    }

    func fetchArtwork(url: URL) async -> Data? {
        guard let (data, response) = try? await session.data(from: url),
              let statusCode = (response as? HTTPURLResponse)?.statusCode,
              (200...299).contains(statusCode) else {
            return nil
        }
        return data
    }

    func likeStatus(trackID: String) async -> Bool? {
        guard let accountID = await accountID(),
              let response = await get(path: "/users/\(accountID)/likes/tracks") else {
            return nil
        }

        return likedTrackIDs(fromLikesResponse: response).contains(trackID)
    }

    func like(trackID: String) async {
        guard let accountID = await accountID() else {
            return
        }
        await post(path: "/users/\(accountID)/likes/tracks/add", form: ["trackId": trackID])
    }

    func unlike(trackID: String) async {
        guard let accountID = await accountID() else {
            return
        }
        await post(path: "/users/\(accountID)/likes/tracks/remove", form: ["trackIds": trackID])
    }
}

private extension YandexMusicClient {
    func accountID() async -> String? {
        if let cachedAccountID {
            return cachedAccountID
        }
        guard let response = await get(path: "/account/status"),
              let result = response["result"] as? [String: Any],
              let account = result["account"] as? [String: Any] else {
            return nil
        }

        let uid = (account["uid"] as? Int).map(String.init) ?? account["uid"] as? String
        cachedAccountID = uid
        return uid
    }

    func firstTrack(fromSearchResponse response: [String: Any]) -> ResolvedTrack? {
        guard let result = response["result"] as? [String: Any],
              let tracks = result["tracks"] as? [String: Any],
              let results = tracks["results"] as? [[String: Any]],
              let first = results.first,
              let id = (first["id"] as? Int).map(String.init) ?? first["id"] as? String else {
            return nil
        }

        let coverURL = (first["coverUri"] as? String).flatMap {
            URL(string: "https://" + $0.replacingOccurrences(of: "%%", with: "1000x1000"))
        }
        return ResolvedTrack(id: id, coverURL: coverURL)
    }

    func likedTrackIDs(fromLikesResponse response: [String: Any]) -> Set<String> {
        guard let result = response["result"] as? [String: Any],
              let library = result["library"] as? [String: Any],
              let tracks = library["tracks"] as? [[String: Any]] else {
            return []
        }
        let ids = tracks.compactMap { item -> String? in
            (item["id"] as? Int).map(String.init) ?? item["id"] as? String
        }
        return Set(ids)
    }

    func authorizedRequest(url: URL) -> URLRequest? {
        guard let token = tokenStore.loadToken() else {
            return nil
        }
        var request = URLRequest(url: url)
        request.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    func get(path: String, query: [String: String] = [:]) async -> [String: Any]? {
        guard var components = URLComponents(url: Constants.baseURL.appendingPathComponent(path),
                                             resolvingAgainstBaseURL: false) else {
            return nil
        }
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url, let request = authorizedRequest(url: url) else {
            return nil
        }

        return await performJSONRequest(request)
    }

    func post(path: String, form: [String: String]) async {
        let url = Constants.baseURL.appendingPathComponent(path)
        guard var request = authorizedRequest(url: url) else {
            return
        }
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = form
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        _ = await performJSONRequest(request)
    }

    func performJSONRequest(_ request: URLRequest) async -> [String: Any]? {
        guard let (data, response) = try? await session.data(for: request) else {
            FileHandle.standardError.write(Data("YandexMusicClient: request failed \(request.url?.path ?? "")\n".utf8))
            return nil
        }

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            FileHandle.standardError.write(Data(
                "YandexMusicClient: \(request.url?.path ?? "") -> \(statusCode): \(body.prefix(300))\n".utf8
            ))
            return nil
        }

        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}
