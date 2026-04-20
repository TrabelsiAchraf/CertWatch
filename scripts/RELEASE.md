# Releasing CertWatch

CertWatch ships as a Developer ID-signed, notarized `.dmg`. It cannot go to the
Mac App Store because it reads the full user Keychain and `~/Library/MobileDevice/…`,
which the App Sandbox forbids.

## One-time setup

1. **Developer ID Application certificate** — create at
   https://developer.apple.com/account/resources/certificates/list
   (Team `D44ZSJA8CM`), download the `.cer`, open it to install in the login
   Keychain alongside its private key.

2. **App-Specific Password** — generate at https://appleid.apple.com
   (Security → App-Specific Passwords). Label it e.g. `CertWatch notarytool`.

3. **Store notary credentials** so `notarytool` can run unattended:

   ```bash
   xcrun notarytool store-credentials "CertWatchNotary" \
     --apple-id "a.trabelsi@oodrive.com" \
     --team-id "D44ZSJA8CM" \
     --password "<app-specific password from step 2>"
   ```

   The credentials are stored in the macOS Keychain; the repo never sees them.

## Cutting a release

From the repo root, with a clean working tree:

```bash
./scripts/release.sh 1.0.0
```

The script:

1. Writes `MARKETING_VERSION=1.0.0` and `CURRENT_PROJECT_VERSION=<git commit count>` into `project.pbxproj`.
2. Archives with `xcodebuild` (Release config, Developer ID identity pinned).
3. Exports via `ExportOptions.plist`.
4. Zips the `.app`, submits to Apple's notary service, waits for the verdict.
5. Staples the notarization ticket into the `.app` so it verifies offline.
6. Packages as `dist/CertWatch-1.0.0.dmg`.
7. Runs `codesign --verify` + `spctl --assess` and prints the SHA-256.

Expected happy-path tail:

```
status: Accepted
The staple and validate action worked!
dist/CertWatch-1.0.0.dmg: accepted
SHA-256: <64 hex chars>
```

Then commit the `project.pbxproj` version bump:

```bash
git add CertWatch.xcodeproj/project.pbxproj
git commit -m "Bump version to 1.0.0"
git tag v1.0.0
```

## Distributing

Upload `dist/CertWatch-1.0.0.dmg` to wherever you host releases (GitHub Releases,
your website, etc.). First-launch UX on a user's Mac:

- Safari marks the DMG as "downloaded from the Internet".
- Double-clicking the `.app` shows a single "Are you sure you want to open it?"
  prompt — *not* "unidentified developer" (that would mean the ticket didn't
  staple; investigate).
- After launch, the menu bar icon appears with no Dock presence
  (thanks to `LSUIElement = YES`).

## Known non-goals

- **Mac App Store** — blocked by App Sandbox incompatibility.
- **Sparkle auto-update** — deferred; requires a hosted appcast + EdDSA key.
- **CI pipeline** — `release.sh` is local-only. A GitHub Actions wrapper with
  secrets can be added later.
