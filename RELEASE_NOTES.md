# SafariBrowser v1.0.0-beta.1 — Signed IPA

Native iOS browser (iOS 18.4+, Swift 6, WKWebView).  
Release contains a **signed `.ipa`** for installation on registered devices.

## Install on iPhone/iPad

1. Download `SafariBrowser.ipa` from this release.
2. Install with one of:
   - **Apple Configurator** (USB)
   - **Xcode** → Window → Devices and Simulators → drag IPA
   - **AltStore / Sideloadly** (uses your Apple ID development cert)
   - **MDM** / enterprise deployment

```bash
# If device is connected and trusted:
xcrun devicectl device install app --device <UDID> SafariBrowser.ipa
```

Your device UDID must be registered in the Apple Developer portal for **Development** provisioning.

## GitHub Actions signing secrets

Repository → Settings → Secrets → Actions:

| Secret | Description |
|--------|-------------|
| `APPLE_TEAM_ID` | 10-character Team ID |
| `BUILD_CERTIFICATE_BASE64` | Apple Development `.p12` (base64) |
| `P12_PASSWORD` | `.p12` export password |
| `KEYCHAIN_PASSWORD` | Any random string for CI keychain |
| `ASC_KEY_ID` | App Store Connect API Key ID |
| `ASC_ISSUER_ID` | App Store Connect Issuer ID |
| `ASC_PRIVATE_KEY` | Contents of `AuthKey_XXXX.p8` |

Export certificate locally:

```bash
base64 -i YourCert.p12 | pbcopy   # → BUILD_CERTIFICATE_BASE64
```

## Build from source

```bash
cd SafariBrowser
brew install xcodegen
xcodegen generate
open SafariBrowser.xcodeproj
```

Requires Xcode 16+ and Apple Developer account for device builds.
