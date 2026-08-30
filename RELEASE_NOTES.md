# SafariBrowser v1.0.0-beta.1 — Unsigned IPA

Native iOS browser (iOS 18.4+, Swift 6, WKWebView).

## Установка (как Private Music)

IPA **не подписан** в GitHub Actions. Подпись — **на устройстве** вашим Apple ID:

- **ESign** / **Sideloadly** / **Feather** / **AltStore**
- или Xcode → Window → Devices and Simulators

| Файл | Описание |
|------|----------|
| `SafariBrowser-*-iphone-unsigned.ipa` | Без Share/Widget — проще для sideload |
| `SafariBrowser-*-unsigned.ipa` | Полная сборка с расширениями |

GitHub Secrets **не нужны**.

## Сборка из исходников

```bash
cd SafariBrowser
brew install xcodegen
xcodegen generate
open SafariBrowser.xcodeproj
```

Requires Xcode 16+ and iOS 18.4 SDK.
