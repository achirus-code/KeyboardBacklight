#!/bin/bash
# Builds KeyboardBacklight.app (release) in the project folder.
set -euo pipefail
cd "$(dirname "$0")"

# UNIVERSAL=1 builds for Apple silicon and Intel (requires Xcode, not just the Command Line Tools)
ARGS=(-c release)
[[ "${UNIVERSAL:-}" == 1 ]] && ARGS+=(--arch arm64 --arch x86_64)
swift build "${ARGS[@]}"
BIN="$(swift build "${ARGS[@]}" --show-bin-path)"
[[ -f Resources/AppIcon.icns ]] || swift Scripts/make-icon.swift

APP=KeyboardBacklight.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/KeyboardBacklight" "$APP/Contents/MacOS/KeyboardBacklight"
cp Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/BuyMeACoffee.png "$APP/Contents/Resources/BuyMeACoffee.png"
cp -R Resources/*.lproj "$APP/Contents/Resources/"
# Ad-hoc signature with a fixed requirement (bundle ID only): this way accessibility
# access is kept after a rebuild.
codesign --force --sign - -r='designated => identifier "de.achirus.keyboardbacklight"' "$APP" >/dev/null
echo "Done: $(pwd)/$APP"

# "./build.sh install" also installs to /Applications and launches the app
if [[ "${1:-}" == "install" ]]; then
    pkill -x KeyboardBacklight || true
    rm -rf "/Applications/$APP"
    ditto "$APP" "/Applications/$APP"
    echo "Installed: /Applications/$APP"
    open "/Applications/$APP"
fi
