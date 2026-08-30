# SafariBrowser

Safari-подобный iOS-браузер на SwiftUI + WKWebView, собранный из лучших паттернов open-source проектов.

## Что внутри

| Фича | Источник паттерна |
|------|-------------------|
| Bottom toolbar + address bar | amerhukic/Browser (Safari UI) |
| TabManager + session restore | mozilla-mobile/firefox-ios |
| Content blocking (WKContentRuleList) | duckduckgo/apple-browsers |
| SwiftUI + LocalPackage архитектура | Kyome22/Telescopure |
| Private mode (nonPersistent data store) | OnionBrowser |
| Userscripts (JS injection) | SlayterDev/RadiumBrowser |
| WebView pool (no reload on tab switch) | Firefox iOS / factoryfloor |

## Функции Phase 1

- Мультивкладочный браузер с горизонтальным свайпом между вкладками
- Tab grid overlay (как в Safari)
- Swipe за последней вкладкой → новая вкладка
- Bottom address bar с умным URL resolver (поиск / URL / localhost / IPv6)
- Закладки и история (SwiftData)
- Content blocking (трекеры и реклама)
- Private browsing mode
- Userscripts — добавление, редактирование, match patterns
- Find in page
- Session restore между запусками
- Выбор поисковика (Google, DuckDuckGo, Bing, Yandex)

## Требования

- iOS 18.0+
- Xcode 16+
- Swift 6.0

## Сборка

### Вариант A: XcodeGen (рекомендуется)

```bash
brew install xcodegen   # если ещё не установлен
cd SafariBrowser
xcodegen generate
open SafariBrowser.xcodeproj
```

Выбрать iPhone Simulator → Run (⌘R).

### Вариант B: Вручную в Xcode

1. File → New → Project → iOS App (SwiftUI, Swift 6)
2. File → Add Package Dependencies → Add Local → выбрать `SafariBrowserCore/`
3. Скопировать содержимое `SafariBrowser/` в проект
4. Добавить `Info.plist` keys из нашего Info.plist

## Структура

```
SafariBrowser/
├── SafariBrowserCore/     # SPM — TabManager, WebViewPool, URLResolver, ContentBlocker
├── SafariBrowser/         # App — Views, SwiftData models, Settings
├── docs/PLAN.md           # Roadmap (Phase 2–4)
└── project.yml            # XcodeGen config
```

## Roadmap

См. [docs/PLAN.md](docs/PLAN.md):

- **Phase 2** — collapsing toolbar, favicons, tab previews, pull-to-refresh
- **Phase 3** — reader mode, share extension, default browser, iCloud sync
- **Phase 4** — WKWebExtension, iPad split view, widgets

## Тесты

```bash
cd SafariBrowserCore
swift test
```

## Лицензия

MIT
