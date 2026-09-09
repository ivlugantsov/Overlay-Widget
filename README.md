# Overlay Widget

Плавающая панель поверх всех окон и Spaces на macOS: управление плеером (Яндекс.Музыка / Spotify / Apple Music) и живые котировки крипты и акций — всегда под рукой, без переключения между приложениями.

![menu bar icon](https://img.shields.io/badge/macOS-13%2B-black)

## Возможности

- **Плеер** — обложка, трек, исполнитель, play/pause/next/prev, перемотка, лайк (Яндекс.Музыка)
- **Панель котировок** — крипта (Binance, без ключей) и зарубежные акции (Finnhub), настраиваемый список тикеров с живым поиском
- Плеер и панель котировок включаются/выключаются независимо друг от друга
- Русский и English, переключение прямо в настройках
- Запуск при входе в систему
- Не занимает Dock — только иконка в меню-баре

## Установка

1. Скачай `Overlay Widget.dmg` со страницы [Releases](https://github.com/ivlugantsov/Overlay-Widget/releases/latest)
2. Открой скачанный `.dmg`
3. Перетащи **Overlay Widget** в папку **Applications**
4. Запусти приложение из Applications (или через Launchpad/Spotlight)
5. При первом запуске macOS покажет предупреждение «неизвестный разработчик» (Gatekeeper) — это нормально для приложений вне App Store. Открой **Системные настройки → Конфиденциальность и безопасность**, пролистай вниз и нажми **«Открыть в любом случае»** рядом с Overlay Widget. Либо кликни правой кнопкой по приложению → **Открыть**.

## Настройка

Открой «Настройки» через иконку в меню-баре:

- **Yandex OAuth-токен** — нужен для лайка/дизлайка треков. Кнопка «Получить токен» откроет страницу авторизации Яндекса — войди и вставь `access_token` из адресной строки после редиректа.
- **Finnhub-токен** — нужен для котировок акций. Кнопка «Получить токен Finnhub» откроет бесплатную регистрацию — скопируй именно **API Key** (не Webhook Secret) из личного кабинета.
- Крипта работает сразу, без токенов.

## Требования

macOS 13 (Ventura) или новее.

## Сборка из исходников

```bash
swift build -c release          # обычная сборка
./Scripts/build_app.sh          # собрать .app в dist/
./Scripts/build_dmg.sh          # собрать .app + .dmg в dist/
```

## Технологии

- SwiftUI + AppKit (`NSPanel`, always-on-top overlay)
- [ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) — доступ к системному MediaRemote в обход ограничений macOS 15.4+
- Неофициальный API Yandex Music (как в [MarshalX/yandex-music-api](https://github.com/MarshalX/yandex-music-api))
- Binance public WebSocket API, Finnhub API

## Обратная связь

iv.lugantsov@gmail.com
