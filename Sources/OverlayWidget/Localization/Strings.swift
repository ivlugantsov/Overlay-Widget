//
//  Strings.swift
//  OverlayWidget
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import Foundation

/// Свой набор строк вместо NSLocalizedString/.strings — тому нужна привязка к системному
/// языку через .lproj-бандлы, а тут язык переключается в рантайме прямо из Настроек.
struct Strings {
    let nothingPlaying: String
    let noActivePlayerOpen: String

    let quotesEmpty: String

    let widgetsTitle: String
    let widgetsDescription: String
    let playerToggle: String
    let marketPanelToggle: String
    let launchAtLoginToggle: String

    let languageTitle: String

    let yandexTokenTitle: String
    let yandexTokenDescription: String
    let getTokenButton: String
    let yandexTokenInstructions: String
    let tokenFieldPlaceholder: String
    let savedLabel: String
    let saveButton: String

    let marketSourcesDescription: String
    let tickersTitle: String
    let tickersEmpty: String
    let finnhubTokenTitle: String
    let getFinnhubTokenButton: String
    let finnhubTokenInstructions: String
    let finnhubTokenFieldPlaceholder: String
    let tickerSearchPlaceholder: String
    let searching: String
    let nothingFound: String
    let saveFinnhubTokenFirst: String

    let cryptoLabel: String
    let stockLabel: String

    let settingsMenuItem: String
    let quitMenuItem: String
    let settingsWindowTitle: String

    let undo: String
    let redo: String
    let cut: String
    let copy: String
    let paste: String
    let selectAll: String

    let infoTitle: String
    let infoDescription: String
    let contactLabel: String
}

extension Strings {
    static let ru = Strings(
        nothingPlaying: "Ничего не играет",
        noActivePlayerOpen: "Нет активного плеера — открыть:",
        quotesEmpty: "Котировки не добавлены",
        widgetsTitle: "Виджеты",
        widgetsDescription: "Можно показывать по отдельности — например только котировки, без плеера.",
        playerToggle: "Плеер",
        marketPanelToggle: "Панель котировок",
        launchAtLoginToggle: "Запускать при входе в систему",
        languageTitle: "Язык",
        yandexTokenTitle: "Yandex OAuth-токен",
        yandexTokenDescription: "Нужен для лайка/дизлайка — MediaRemote его не даёт.",
        getTokenButton: "Получить токен",
        yandexTokenInstructions: "Войди под своим аккаунтом, разреши доступ — из адресной строки после "
            + "редиректа скопируй значение access_token и вставь ниже.",
        tokenFieldPlaceholder: "Токен",
        savedLabel: "Сохранено",
        saveButton: "Сохранить",
        marketSourcesDescription: "Крипта — Binance (без ключа), зарубежные акции — Finnhub.",
        tickersTitle: "Тикеры",
        tickersEmpty: "Пока ничего не добавлено",
        finnhubTokenTitle: "Finnhub-токен (для акций)",
        getFinnhubTokenButton: "Получить токен Finnhub",
        finnhubTokenInstructions: "Зарегистрируйся (бесплатно) и скопируй именно API Key (не Webhook Secret) из Dashboard.",
        finnhubTokenFieldPlaceholder: "Finnhub-токен",
        tickerSearchPlaceholder: "Начни вводить символ…",
        searching: "Ищу…",
        nothingFound: "Ничего не найдено",
        saveFinnhubTokenFirst: "Сначала сохрани токен Finnhub ниже",
        cryptoLabel: "Крипта",
        stockLabel: "Акция",
        settingsMenuItem: "Настройки…",
        quitMenuItem: "Закрыть",
        settingsWindowTitle: "Настройки",
        undo: "Отменить",
        redo: "Повторить",
        cut: "Вырезать",
        copy: "Копировать",
        paste: "Вставить",
        selectAll: "Выделить всё",
        infoTitle: "О приложении",
        infoDescription: "Плавающая панель поверх всех окон: управление плеером "
            + "(Яндекс.Музыка / Spotify / Apple Music) и живые котировки крипты и акций.",
        contactLabel: "Связь"
    )

    static let en = Strings(
        nothingPlaying: "Nothing playing",
        noActivePlayerOpen: "No active player — open:",
        quotesEmpty: "No quotes added",
        widgetsTitle: "Widgets",
        widgetsDescription: "Can be shown independently — e.g. quotes only, without the player.",
        playerToggle: "Player",
        marketPanelToggle: "Quotes panel",
        launchAtLoginToggle: "Launch at Login",
        languageTitle: "Language",
        yandexTokenTitle: "Yandex OAuth token",
        yandexTokenDescription: "Needed for like/unlike — MediaRemote doesn't provide it.",
        getTokenButton: "Get token",
        yandexTokenInstructions: "Sign in with your account, grant access — copy the access_token value "
            + "from the address bar after the redirect and paste it below.",
        tokenFieldPlaceholder: "Token",
        savedLabel: "Saved",
        saveButton: "Save",
        marketSourcesDescription: "Crypto — Binance (no key needed), foreign stocks — Finnhub.",
        tickersTitle: "Tickers",
        tickersEmpty: "Nothing added yet",
        finnhubTokenTitle: "Finnhub token (for stocks)",
        getFinnhubTokenButton: "Get Finnhub token",
        finnhubTokenInstructions: "Sign up (free) and copy the actual API Key (not the Webhook Secret) from the Dashboard.",
        finnhubTokenFieldPlaceholder: "Finnhub token",
        tickerSearchPlaceholder: "Start typing a symbol…",
        searching: "Searching…",
        nothingFound: "Nothing found",
        saveFinnhubTokenFirst: "Save the Finnhub token below first",
        cryptoLabel: "Crypto",
        stockLabel: "Stock",
        settingsMenuItem: "Settings…",
        quitMenuItem: "Quit",
        settingsWindowTitle: "Settings",
        undo: "Undo",
        redo: "Redo",
        cut: "Cut",
        copy: "Copy",
        paste: "Paste",
        selectAll: "Select All",
        infoTitle: "About",
        infoDescription: "A floating panel above all windows: control your player "
            + "(Yandex Music / Spotify / Apple Music) and live crypto and stock quotes.",
        contactLabel: "Contact"
    )
}

extension AppLanguage {
    var strings: Strings {
        switch self {
        case .ru: return .ru
        case .en: return .en
        }
    }
}
