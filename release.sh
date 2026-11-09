#!/bin/bash
# Builds a Developer ID signed, notarized and stapled Radish DMG for GitHub Releases.
# The file is always build/Radish.dmg so releases/latest/download/Radish.dmg stays valid.
#
#   NOTARY_PROFILE=Cherry-Notary ./release.sh 0.1.0
#
#   NOTARY_PROFILE      keychain profile name for notarytool (default: Cherry-Notary)
#   CODESIGN_IDENTITY   defaults to the first "Developer ID Application" identity
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:?usage: ./release.sh <version>   e.g. ./release.sh 0.1.0}"
NOTARY_PROFILE="${NOTARY_PROFILE:-Cherry-Notary}"
if [ -z "${CODESIGN_IDENTITY:-}" ]; then
  CODESIGN_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
    | grep -m1 -oE '"Developer ID Application: [^"]+"' | tr -d '"' || true)
fi
[ -n "$CODESIGN_IDENTITY" ] || { echo "no Developer ID Application identity in the keychain" >&2; exit 1; }

BUILD_NUMBER="$(git rev-list --count HEAD)"
CODESIGN_IDENTITY="$CODESIGN_IDENTITY" VERSION="$VERSION" BUILD_NUMBER="$BUILD_NUMBER" UNIVERSAL=1 ./build.sh

APP="build/Radish.app"
DMG="build/Radish.dmg"

# Notarize the app on its own first and staple its ticket, so it opens even when
# someone launches it for the first time without a network connection.
echo "▸ notarizing the app"
ditto -c -k --keepParent "$APP" build/Radish-app.zip
xcrun notarytool submit build/Radish-app.zip --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
rm -f build/Radish-app.zip

echo "▸ packaging $DMG"
Tools/make_dmg.sh "$APP" "$DMG" >/dev/null
codesign --force --timestamp --sign "$CODESIGN_IDENTITY" "$DMG"

echo "▸ notarizing the DMG (takes a few minutes)"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature --verbose "$DMG"

echo "✓ $DMG"
echo "  sha256 $(shasum -a 256 "$DMG" | cut -d' ' -f1)"
