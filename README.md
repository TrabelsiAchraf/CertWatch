# CertWatch

A macOS menu-bar app that silently monitors your Apple Developer certificates and provisioning profiles, and alerts you before anything expires.

Built for iOS / macOS developers who juggle multiple developer accounts and don't want to be surprised by a broken build the morning of a release.

<p align="center">
  <img src=".github/screenshot.png" width="380" alt="CertWatch popover" />
</p>

## Features

- Reads certificates from your macOS Keychain and provisioning profiles from `~/Library/MobileDevice/Provisioning Profiles` and `~/Library/Developer/Xcode/UserData/Provisioning Profiles`.
- Groups everything by developer account, with an automatically assigned color per team.
- **Overview** tab: 90-day horizon histogram, four at-a-glance stats (valid / expiring / broken / expired), "Needs attention" and "Broken profiles" sections.
- **Certificates** tab: click any certificate to see exactly which provisioning profiles reference it, its SHA-1, serial, and dates.
- **Profiles** tab: grouped list with bundle ID, type, health bar, and expiry.
- Local notifications at 30 days, 7 days, and 1 day before expiration.
- No Apple login required — everything is read locally from the Keychain and filesystem.

## Install

1. Download the latest `CertWatch-<version>.dmg` from the [Releases page](../../releases).
2. Open the DMG and drag `CertWatch.app` into `/Applications`.
3. Launch it. macOS will prompt once for "downloaded from the Internet" — confirm.
4. The CertWatch icon appears in your menu bar. Click it to open the popover.

CertWatch is a pure menu-bar agent: no Dock icon, no app menu.

## Privacy

CertWatch is read-only and runs entirely offline. It never uploads anything anywhere. No telemetry, no analytics. Credentials in your Keychain are queried via `SecItemCopyMatching` and never leave the machine.

## Build from source

Requires Xcode 26.x on macOS.

```bash
git clone https://github.com/<your-user>/CertWatch.git
cd CertWatch
open CertWatch.xcodeproj
```

Hit `Cmd + R` to build and run.

## Releasing

See [`scripts/RELEASE.md`](scripts/RELEASE.md) for the Developer ID signing + notarization pipeline.

## License

[MIT](LICENSE)
