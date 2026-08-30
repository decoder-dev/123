# SafariBrowser v1.0.0-beta.1

Native iOS browser (iOS 18+, Swift 6, WKWebView).

## Install (Simulator)

1. Download `SafariBrowser-Simulator.zip` from this release.
2. Unzip and drag `SafariBrowser.app` onto an iOS Simulator, or:
   ```bash
   xcrun simctl install booted SafariBrowser.app
   xcrun simctl launch booted com.safaribrowser.app
   ```

## Build from source

```bash
cd SafariBrowser
brew install xcodegen
xcodegen generate
open SafariBrowser.xcodeproj
```

Requires Xcode 16+ and iOS 18 SDK.

## Highlights

- Tab management with session restore and private mode
- Content blocking, reader mode, find-in-page, downloads
- Share extension, widget, App Intents, iPad split view
- iCloud bookmark sync

## Known limitations (beta)

- Simulator build only (no device signing in CI)
- Web Extensions require bundled `.webextension` in app folder
- Default browser requires manual iOS Settings configuration
