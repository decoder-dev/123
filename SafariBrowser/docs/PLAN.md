# SafariBrowser — Master Plan

Safari-подобный iOS-браузер, собранный из лучших паттернов open-source проектов.

## Статус: ✅ Complete (v1.0)

Все 4 фазы реализованы.

## Источники вдохновения

| Проект | Что взяли |
|--------|-----------|
| **amerhukic/Browser** | Bottom toolbar, collapsing chrome, tab carousel |
| **mozilla-mobile/firefox-ios** | TabManager, session restore, find-in-page, WebView pool |
| **duckduckgo/apple-browsers** | WKContentRuleList content blocking |
| **Kyome22/Telescopure** | SwiftUI + LocalPackage, default browser, search engine |
| **OnionBrowser** | Private mode, per-site permissions |
| **SlayterDev/RadiumBrowser** | Userscripts pipeline |
| **Shitsuten/pocket-browser** | Web Extensions architecture |

## Архитектура

```
SafariBrowserApp
  ├─ TabManager, ChromeState, DownloadManager
  ├─ ContentBlockerService, UserscriptManager, WebExtensionManager
  └─ BrowserRootView
       ├─ BrowserSplitView (iPad)
       └─ BrowserContainerView (iPhone)
            ├─ TabPagerView → BrowserWebView (scroll, pull-refresh, downloads)
            ├─ AddressBarView + BrowserToolbarView (collapsing)
            ├─ TabGridView (favicons + previews)
            ├─ FindInPageBar
            └─ ReaderView
```

## Фазы

### Phase 1 — Foundation ✅
- Swift Package `SafariBrowserCore`
- TabManager, WebViewPool, URLResolver
- BrowserWebView + Coordinator
- Tab pager + toolbar + address bar
- Tab grid overlay
- SwiftData: bookmarks, history, userscripts
- Content blocking, private mode, find-in-page, settings, session restore

### Phase 2 — Safari UI polish ✅
- Collapsing toolbar on scroll (`ChromeState`)
- Tab creation animation (swipe past last tab)
- Favicon fetching + tab preview snapshots
- Pull-to-refresh (`UIRefreshControl`)
- Haptic feedback on tab switch / new tab / toolbar toggle

### Phase 3 — Power features ✅
- Reader mode (DOM extraction + `ReaderView`)
- Share extension (`SafariBrowserShare`)
- Default browser entitlement + URL handlers
- iCloud bookmark sync (`CloudSyncService` + KVS)
- Per-site permissions UI (`SitePermissionStore`)
- Download manager (`DownloadManager` + `DownloadsView`)

### Phase 4 — Advanced ✅
- Web Extensions loader (`WebExtensionManager`, iOS 18+)
- iPad split view (`BrowserSplitView`)
- Home screen widget (`SafariBrowserWidget`)
- Shortcuts / App Intents (`OpenURLIntent`, `NewTabIntent`)

## Targets

| Target | Purpose |
|--------|---------|
| SafariBrowser | Main app |
| SafariBrowserCore | Shared Swift package |
| SafariBrowserShare | Share extension |
| SafariBrowserWidget | WidgetKit extension |
| SafariBrowserCoreTests | Unit tests |

## Сборка

```bash
cd SafariBrowser
xcodegen generate
open SafariBrowser.xcodeproj
```

Requires iOS 18+, Xcode 16+, Swift 6.
Set your Development Team in Xcode for entitlements (default browser, iCloud, app groups).
