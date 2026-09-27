# KeyboardBacklight

A macOS menu bar app that puts keyboard backlight control back on the keys – like it used to be:

- **F5** → darker
- **F6** → brighter
- 16 steps, finer steps with ⌥⇧
- Overlay with a brightness bar, menu bar icon in the style of the old macOS symbol
- Keys can be reassigned, icon can be hidden, launch at login
- Optionally switches back to automatic brightness after a chosen time (5 minutes to 8 hours)
- In English, German, French, Spanish and Italian (follows the system language)

Tested on a MacBook Air M3 with macOS 26.

## Download

**[KeyboardBacklight.zip](https://github.com/achirus-code/KeyboardBacklight/releases/latest/download/KeyboardBacklight.zip)** – latest version for Apple silicon and Intel.

1. Unzip and move the app to your Applications folder.
2. The app isn't notarized by Apple, so macOS blocks the first launch: close the message, then click **Open Anyway** in *System Settings › Privacy & Security*.
3. Allow **Accessibility** access – without it the keys can't be captured.

Website: https://achirus-code.github.io/KeyboardBacklight/en/ (English) · https://achirus-code.github.io/KeyboardBacklight/ (Deutsch)

## Building

Only needs the Xcode Command Line Tools.

```bash
./build.sh               # builds KeyboardBacklight.app in the project folder
./build.sh install       # also installs to /Applications and launches the app
UNIVERSAL=1 ./build.sh   # for Apple silicon and Intel (requires Xcode)
```

On first launch macOS asks for **Accessibility** access – without it the keys can't be captured.

## How it works

- Brightness through the private framework `CoreBrightness` (`KeyboardBrightnessClient`)
- Keys through a `CGEventTap`: F5 = Dictation (key code 176), F6 = Do Not Disturb (key code 178); with "Use F1, F2, etc. keys as standard function keys" the regular codes 96 and 97
- In bright ambient light the automatic keyboard brightness keeps the backlight off, so it is turned off on the first key press (can be turned back on in the menu)
- App icon: `swift Scripts/make-icon.swift`

## Website

The project website lives in `docs/` – static HTML, CSS and JavaScript with no build step and no external dependencies. It includes an interactive preview of the app (keyboard, overlay, menu bar icon, settings). German at `docs/index.html`, English at `docs/en/index.html` – both share `style.css` and `app.js`, which picks its texts from `<html lang>`. Visitors without a German browser language are sent to the English page on their first visit; the DE | EN switch remembers the choice.

```bash
python3 -m http.server -d docs   # view locally: http://localhost:8000
```

It is published with GitHub Actions (`.github/workflows/pages.yml`) whenever `docs/` changes on `main`. One-time setup: *Settings → Pages → Source: GitHub Actions*.

## Releases

`.github/workflows/release.yml` builds the app on a Mac runner for Apple silicon and Intel:

- **Pull requests:** test build, downloadable as a workflow artifact
- **Push to `main`:** if there is no release yet for the version in `Info.plist` (`CFBundleShortVersionString`), it creates the release `v<version>` with `KeyboardBacklight.zip`

To ship a new version, bump `CFBundleShortVersionString` in `Info.plist` and merge to `main`.
