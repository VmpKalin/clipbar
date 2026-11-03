#!/bin/zsh
# Builds a signed, notarized ClipBar DMG for distribution outside the Mac App Store.
#
#     scripts/release.sh            Developer ID build, notarized and stapled
#     scripts/release.sh --local    same pipeline with the Apple Development identity, no notarization
#                                   (checks the build, signature and DMG; Gatekeeper will still reject it)
#
# One-time setup (see docs/release.md):
#   1. Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application
#   2. xcrun notarytool store-credentials clipbar --apple-id <apple-id> --team-id <team-id>
#
# Environment overrides: NOTARY_PROFILE (default "clipbar"), SIGN_IDENTITY, OUT_DIR (default build/release).
set -euo pipefail

ROOT=${0:A:h:h}
cd "$ROOT"

LOCAL=false
[[ "${1:-}" == "--local" ]] && LOCAL=true

PROFILE=${NOTARY_PROFILE:-clipbar}
OUT=${OUT_DIR:-$ROOT/build/release}
# DerivedData must stay outside ~/Desktop: its provenance attributes break codesign.
DD=${DERIVED_DATA:-$TMPDIR/clipbar-release-dd}
VERSION=$(awk -F'"' '/MARKETING_VERSION/ {print $2; exit}' project.yml)

if $LOCAL; then
  IDENTITY=${SIGN_IDENTITY:-Apple Development}
else
  IDENTITY=${SIGN_IDENTITY:-Developer ID Application}
fi

step() { print -P "%F{cyan}==>%f $1" }
fail() { print -P "%F{red}error:%f $1" >&2; exit 1 }

if ! security find-identity -v -p codesigning | grep -q "\"$IDENTITY"; then
  fail "no \"$IDENTITY\" certificate in the keychain.
  Create one in Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application
  (needs a paid Apple Developer Program membership), or run with --local to test the pipeline."
fi
if ! $LOCAL && ! xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
  fail "no notarytool profile \"$PROFILE\". Run:
  xcrun notarytool store-credentials $PROFILE --apple-id <apple-id> --team-id <team-id>"
fi

step "Generating project"
xcodegen generate --quiet

step "Building ClipBar $VERSION (Release, signed with \"$IDENTITY\")"
rm -rf "$DD/Build/Products/Release/ClipBar.app"
xcodebuild -scheme ClipBar -destination 'generic/platform=macOS' -configuration Release \
  -derivedDataPath "$DD" \
  CODE_SIGN_IDENTITY="$IDENTITY" ENABLE_HARDENED_RUNTIME=YES OTHER_CODE_SIGN_FLAGS="--timestamp" \
  build -quiet

APP="$DD/Build/Products/Release/ClipBar.app"
[[ -d "$APP" ]] || fail "build produced no app at $APP"

step "Checking signature"
lipo -archs "$APP/Contents/MacOS/ClipBar"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -d --verbose=2 "$APP" 2>&1 | grep -E "Authority=|flags=|TeamIdentifier=" | head -4

step "Running self-test"
"$APP/Contents/MacOS/ClipBar" --selftest

step "Creating DMG"
mkdir -p "$OUT"
DMG="$OUT/ClipBar-$VERSION.dmg"
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "ClipBar $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" -quiet
rm -rf "$STAGE"
codesign --sign "$IDENTITY" --timestamp "$DMG"

if $LOCAL; then
  step "Done (local): $DMG"
  print "Not notarized — other Macs will block it. Run without --local for a distributable build."
  exit 0
fi

step "Notarizing (usually 1–5 minutes)"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait

step "Stapling"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

step "Gatekeeper check"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"

shasum -a 256 "$DMG"
step "Done: $DMG"
