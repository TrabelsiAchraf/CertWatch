#!/usr/bin/env bash
# CertWatch release pipeline: archive → export → notarize → staple → DMG.
#
# Usage: ./scripts/release.sh <version>   e.g. ./scripts/release.sh 1.0.0
# Prerequisites are documented in scripts/RELEASE.md.

set -euo pipefail

PROJECT="CertWatch.xcodeproj"
SCHEME="CertWatch"
BUNDLE_NAME="CertWatch"
TEAM_ID="QN66UQNDZR"
NOTARY_PROFILE="CertWatchNotary"

log() { printf '\033[1;34m▶ %s\033[0m\n' "$*"; }
err() { printf '\033[1;31m✘ %s\033[0m\n' "$*" >&2; exit 1; }

# ─── Pre-flight ──────────────────────────────────────────────────────────────

VERSION="${1-}"
[[ -n "$VERSION" ]] || err "Usage: $0 <version>  (e.g. $0 1.0.0)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?$ ]] \
    || err "Version '$VERSION' must be semver-ish (major.minor.patch[-suffix])."

cd "$(dirname "$0")/.."
REPO_ROOT="$(pwd)"

[[ -d "$PROJECT" ]] || err "Run from the repo root; $PROJECT not found."

if [[ -n "$(git status --porcelain)" ]]; then
    err "Git tree is dirty. Commit or stash before releasing."
fi

if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" --quiet 2>/dev/null | head -n 1 > /dev/null; then
    err "notarytool profile '$NOTARY_PROFILE' not configured. See scripts/RELEASE.md."
fi

BUILD_NUMBER="$(git rev-list --count HEAD)"
log "Releasing version $VERSION (build $BUILD_NUMBER)"

# ─── Inject version into pbxproj ─────────────────────────────────────────────

log "Writing MARKETING_VERSION=$VERSION and CURRENT_PROJECT_VERSION=$BUILD_NUMBER"
sed -i '' -E "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = $VERSION;/g" \
    "$PROJECT/project.pbxproj"
sed -i '' -E "s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = $BUILD_NUMBER;/g" \
    "$PROJECT/project.pbxproj"

# ─── Clean output dirs ───────────────────────────────────────────────────────

rm -rf build
mkdir -p build dist

ARCHIVE="$REPO_ROOT/build/CertWatch.xcarchive"
EXPORT_DIR="$REPO_ROOT/build/export"
APP="$EXPORT_DIR/$BUNDLE_NAME.app"
ZIP="$REPO_ROOT/build/CertWatch.zip"
DMG="$REPO_ROOT/dist/$BUNDLE_NAME-$VERSION.dmg"

# ─── Archive ─────────────────────────────────────────────────────────────────

log "xcodebuild archive"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE" \
    -destination 'generic/platform=macOS' \
    archive \
    | xcbeautify --quiet 2>/dev/null || xcodebuild \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration Release \
        -archivePath "$ARCHIVE" \
        -destination 'generic/platform=macOS' \
        archive

# ─── Export ──────────────────────────────────────────────────────────────────

log "xcodebuild -exportArchive"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist ExportOptions.plist

[[ -d "$APP" ]] || err "Exported app not found at $APP"

# ─── Zip for notary ──────────────────────────────────────────────────────────

log "ditto zip → $(basename "$ZIP")"
ditto -c -k --keepParent "$APP" "$ZIP"

# ─── Notarize ────────────────────────────────────────────────────────────────

log "xcrun notarytool submit (wait)"
SUBMIT_OUTPUT="$(xcrun notarytool submit "$ZIP" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait 2>&1)"
echo "$SUBMIT_OUTPUT"

SUBMISSION_ID="$(echo "$SUBMIT_OUTPUT" | awk '/id:/ {print $2; exit}')"
STATUS="$(echo "$SUBMIT_OUTPUT" | awk '/status:/ {print $2; exit}')"

if [[ "$STATUS" != "Accepted" ]]; then
    log "Fetching notary log for $SUBMISSION_ID"
    xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$NOTARY_PROFILE" || true
    err "Notarization failed (status: $STATUS)"
fi

# ─── Staple ──────────────────────────────────────────────────────────────────

log "xcrun stapler staple"
xcrun stapler staple "$APP"

# ─── DMG ─────────────────────────────────────────────────────────────────────

log "hdiutil create → $(basename "$DMG")"
rm -f "$DMG"
hdiutil create \
    -volname "$BUNDLE_NAME" \
    -srcfolder "$APP" \
    -ov -format UDZO \
    "$DMG"

# ─── Verify ──────────────────────────────────────────────────────────────────

log "Verifying signatures and Gatekeeper acceptance"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -dv --verbose=4 "$APP" 2>&1 | grep -E 'Authority|Signature|TeamIdentifier|Identifier'
spctl --assess --type execute -vv "$APP"

log "Done. Artifact: $DMG"
log "SHA-256: $(shasum -a 256 "$DMG" | awk '{print $1}')"
