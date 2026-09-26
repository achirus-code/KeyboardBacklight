#!/bin/bash
# Baut KeyboardBacklight.app (Release) im Projektordner.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
[[ -f Resources/AppIcon.icns ]] || swift Scripts/make-icon.swift

APP=KeyboardBacklight.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/KeyboardBacklight "$APP/Contents/MacOS/KeyboardBacklight"
cp Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Ad-hoc-Signatur mit fester Anforderung (nur Bundle-ID): So bleibt der
# Bedienungshilfen-Zugriff auch nach einem Neubau erhalten.
codesign --force --sign - -r='designated => identifier "de.achirus.keyboardbacklight"' "$APP" >/dev/null
echo "Fertig: $(pwd)/$APP"

# Mit "./build.sh install" nach /Applications installieren und starten
if [[ "${1:-}" == "install" ]]; then
    pkill -x KeyboardBacklight || true
    rm -rf "/Applications/$APP"
    ditto "$APP" "/Applications/$APP"
    echo "Installiert: /Applications/$APP"
    open "/Applications/$APP"
fi
