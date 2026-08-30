# SafariBrowser — Master Plan

Safari-подобный iOS-браузер, собранный из лучших паттернов open-source проектов.

## Источники вдохновения

| Проект | Что берём |
|--------|-----------|
| **amerhukic/Browser** | Bottom toolbar, collapsing chrome, tab carousel, swipe-to-new-tab |
| **mozilla-mobile/firefox-ios** | TabManager как single source of truth, session restore, find-in-page |
| **duckduckgo/apple-browsers** | Content blocking через WKContentRuleList, privacy services |
| **Kyome22/Telescopure** | SwiftUI + LocalPackage, default browser, search engine picker |
| **OnionBrowser** | Per-site data isolation, aggressive tracker blocking |
| **SlayterDev/RadiumBrowser** | User-editable userscripts, JS injection pipeline |
| **Shitsuten/pocket-browser** | Userscript manager architecture |

## Архитектура

```
SafariBrowserApp
  └─ BrowserRootView
       ├─ TabManager (@Observable, environment)
       ├─ ContentBlockerService
       ├─ UserscriptManager
       └─ BrowserContainerView
            ├─ TabPagerView          ← горизонтальный свайп между вкладками
            │    └─ BrowserWebView   ← UIViewRepresentable + WebViewPool
            ├─ AddressBarView        ← bottom URL bar (Safari-style)
            ├─ BrowserToolbarView    ← back/forward/share/tabs/bookmarks
            ├─ TabGridView           ← overlay: сетка вкладок
            └─ FindInPageBar         ← поиск на странице
```

### Ключевые паттерны

1. **One WKWebView per tab** — `WebViewPool` кэширует инстансы, не пересоздаёт при свайпе
2. **Lazy WebView init** — webview создаётся при первом показе вкладки (экономия памяти)
3. **Profile isolation** — `WKWebsiteDataStore.default()` vs `.nonPersistent()` для private mode
4. **Config copy pattern** — все конфиги WKWebView наследуются от base через `.copy()`

## Фазы реализации

### Phase 1 — Foundation ✅ (этот PR)
- [x] Swift Package `SafariBrowserCore`
- [x] TabManager, WebViewPool, URLResolver
- [x] BrowserWebView + Coordinator (navigation, UI delegate, target=_blank)
- [x] Tab pager + bottom toolbar + address bar
- [x] Tab grid overlay
- [x] SwiftData: bookmarks, history, userscripts
- [x] Content blocking (WKContentRuleList)
- [x] Private browsing mode
- [x] Userscript injection
- [x] Find in page
- [x] Settings (search engine, privacy toggles)
- [x] Session restore

### Phase 2 — Safari UI polish
- [ ] Collapsing toolbar on scroll (UIScrollViewDelegate tracking)
- [ ] Tab creation animation (swipe past last tab)
- [ ] Favicon fetching + tab previews
- [ ] Pull-to-refresh gesture
- [ ] Haptic feedback on tab switch

### Phase 3 — Power features
- [ ] Reader mode (DOM extraction)
- [ ] Share extension
- [ ] Default browser entitlement
- [ ] iCloud sync (bookmarks/history)
- [ ] Per-site permissions UI
- [ ] Download manager

### Phase 4 — Advanced
- [ ] Web Extensions (WKWebExtension — iOS 18+)
- [ ] Split view on iPad
- [ ] Widgets / Shortcuts integration

## Структура проекта

```
SafariBrowser/
├── docs/
│   └── PLAN.md
├── SafariBrowserCore/          # SPM — переиспользуемая логика
│   ├── Package.swift
│   └── Sources/SafariBrowserCore/
│       ├── Models/
│       ├── Managers/
│       ├── Services/
│       └── WebKit/
├── SafariBrowser/              # App target
│   ├── SafariBrowserApp.swift
│   ├── Info.plist
│   ├── Models/                 # SwiftData entities
│   └── Views/
├── project.yml                 # XcodeGen
└── README.md
```

## Требования

- iOS 18.0+
- Xcode 16+
- Swift 6.0

## Сборка

```bash
cd SafariBrowser
# Если установлен XcodeGen:
xcodegen generate
open SafariBrowser.xcodeproj
# Выбрать симулятор iPhone → Run
```

Без XcodeGen: создать новый iOS App проект в Xcode, добавить SafariBrowserCore как local package, скопировать файлы из `SafariBrowser/`.
