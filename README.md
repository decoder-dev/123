# SafariBrowser

Native iOS browser built with SwiftUI and WebKit.

## Features

- Multi-tab browsing with swipe navigation and tab grid
- Safari-style bottom toolbar with collapsing chrome on scroll
- Pull-to-refresh, find in page, reader mode
- Content blocking, private browsing, per-site permissions
- Bookmarks, history, downloads, iCloud sync
- Userscripts and Web Extensions (iOS 18+)
- Share extension, home screen widget, Siri Shortcuts
- iPad split view with sidebar tabs

## Requirements

- iOS 18.0+
- Xcode 16+
- Swift 6.0

## Build

```bash
brew install xcodegen
cd SafariBrowser
xcodegen generate
open SafariBrowser.xcodeproj
```

Set your Development Team in Signing & Capabilities, then run on a simulator or device.

## Project layout

```
SafariBrowser/
├── SafariBrowser/          App target
├── SafariBrowserCore/      Swift Package
├── SafariBrowserShare/     Share extension
├── SafariBrowserWidget/    Widget extension
└── project.yml             XcodeGen config
```

## Tests

```bash
cd SafariBrowser/SafariBrowserCore && swift test
```

## License

MIT © decoder-dev
