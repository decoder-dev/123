# SafariBrowser

Safari-подобный iOS-браузер на SwiftUI + WKWebView — полная реализация, собранная из лучших паттернов open-source проектов.

## Features

### Browsing
- Multi-tab browser with horizontal swipe between tabs
- Tab grid overlay with favicon + page preview snapshots
- Swipe past last tab to create new tab (with animation)
- Bottom address bar + toolbar (Safari-style)
- Collapsing toolbar on scroll down
- Pull-to-refresh
- Smart URL bar (search / URL / localhost / IPv6)
- Find in page
- Reader mode
- Session restore between launches

### Privacy & Security
- Content blocking (WKContentRuleList — trackers & ads)
- Private browsing mode (nonPersistent data store)
- Per-site permissions (camera, mic, location)
- Clear browsing data

### Data
- Bookmarks + History (SwiftData)
- iCloud bookmark sync (NSUbiquitousKeyValueStore)
- Download manager

### Power User
- User-editable userscripts (match patterns, document start/end)
- Web Extensions support (iOS 18+, bundled in `Resources/Extensions/`)
- Search engine picker (Google, DuckDuckGo, Bing, Yandex)

### Platform
- Default browser entitlement (http/https handler)
- Share extension
- Home screen widget (recent page)
- Siri Shortcuts / App Intents
- iPad split view with sidebar tabs

## Architecture

| Source Project | Pattern Used |
|----------------|-------------|
| amerhukic/Browser | Safari UI, collapsing toolbar |
| firefox-ios | TabManager, WebView pool, session restore |
| duckduckgo/apple-browsers | Content blocking |
| Telescopure | SwiftUI + LocalPackage |
| OnionBrowser | Private mode, permissions |
| RadiumBrowser | Userscripts |
| pocket-browser | Web Extensions |

## Requirements

- iOS 18.0+
- Xcode 16+
- Swift 6.0
- Apple Developer account (for entitlements: default browser, iCloud, app groups)

## Build

```bash
brew install xcodegen
cd SafariBrowser
xcodegen generate
open SafariBrowser.xcodeproj
```

1. Set your **Development Team** in Signing & Capabilities
2. Select iPhone or iPad Simulator
3. Run (⌘R)

## Project Structure

```
SafariBrowser/
├── SafariBrowserCore/       # SPM — TabManager, WebViewPool, services
├── SafariBrowser/           # Main app
├── SafariBrowserShare/      # Share extension
├── SafariBrowserWidget/     # WidgetKit extension
├── docs/PLAN.md             # Full roadmap (all phases complete)
└── project.yml              # XcodeGen
```

## Tests

```bash
cd SafariBrowserCore && swift test
```

## Default Browser

After installing on a device:
**Settings → Apps → Default Browser → SafariBrowser**

## License

MIT
