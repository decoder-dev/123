# Architecture

```
SafariBrowserApp
  ├─ TabManager, ChromeState, DownloadManager
  ├─ ContentBlockerService, UserscriptManager, WebExtensionManager
  └─ BrowserRootView
       ├─ BrowserSplitView (iPad)
       └─ BrowserContainerView (iPhone)
            ├─ TabPagerView → BrowserWebView
            ├─ AddressBarView + BrowserToolbarView
            ├─ TabGridView
            ├─ FindInPageBar
            └─ ReaderView
```

## Targets

| Target | Role |
|--------|------|
| SafariBrowser | Main application |
| SafariBrowserCore | Shared Swift package |
| SafariBrowserShare | Share extension |
| SafariBrowserWidget | Home screen widget |
| SafariBrowserCoreTests | Unit tests |

## Core modules

- **TabManager** — tab lifecycle and session snapshots
- **WebViewPool** — one cached WKWebView per tab
- **ChromeState** — bottom toolbar visibility on scroll
- **URLResolver** — address bar input to URL or search query
- **ContentBlockerService** — WKContentRuleList blocking
- **DownloadManager** — file downloads via WKDownload
- **CloudSyncService** — iCloud KVS bookmark sync
- **SitePermissionStore** — per-site camera, mic, location policy
- **UserscriptManager** — JavaScript injection pipeline
- **WebExtensionManager** — bundled .webextension loader
