# KeyboardBacklight

Menüleisten-App für macOS, die die Tastaturbeleuchtung wieder per Taste steuert – wie früher:

- **🌙 Mond-Taste (F6)** → dunkler
- **◀◀ Zurück-Taste (F7)** → heller
- 16 Stufen, mit ⌥⇧ feinere Schritte
- Einblendung mit Helligkeitsbalken, Menüleisten-Icon im Stil des alten macOS-Symbols
- Tasten frei belegbar, Icon ausblendbar, Autostart beim Anmelden

Getestet auf MacBook Air M3 mit macOS 26.

## Download

**[KeyboardBacklight.zip](https://github.com/achirus-code/KeyboardBacklight/releases/latest/download/KeyboardBacklight.zip)** – neueste Version für Apple-Chip und Intel. Entpacken, in „Programme“ ziehen und beim ersten Start unter *Systemeinstellungen › Datenschutz & Sicherheit* auf „Dennoch öffnen“ klicken (die App ist nicht notarisiert).

Website: https://achirus-code.github.io/KeyboardBacklight/

## Bauen

Benötigt nur die Xcode Command Line Tools.

```bash
./build.sh           # baut KeyboardBacklight.app im Projektordner
./build.sh install   # zusätzlich nach /Applications installieren und starten
UNIVERSAL=1 ./build.sh   # für Apple-Chip und Intel (benötigt Xcode)
```

Beim ersten Start fragt macOS nach dem **Bedienungshilfen-Zugriff** – ohne ihn können die Tasten nicht abgefangen werden.

## Technik

- Helligkeit über das private Framework `CoreBrightness` (`KeyboardBrightnessClient`)
- Tasten über einen `CGEventTap` (Mond-Taste = Tastencode 178, Zurück = Media-Key `NX_KEYTYPE_REWIND`)
- Bei hellem Umgebungslicht hält die Helligkeitsautomatik die Beleuchtung aus; sie wird deshalb beim ersten Tastendruck abgeschaltet (im Menü wieder aktivierbar)
- App-Icon: `swift Scripts/make-icon.swift`

## Website

Die Projektseite liegt in `docs/` – statisches HTML, CSS und JavaScript ohne Build-Schritt und ohne externe Abhängigkeiten. Sie enthält eine interaktive Vorschau der App (Tastatur, Einblendung, Menüleisten-Symbol, Einstellungsfenster).

```bash
python3 -m http.server -d docs   # lokal ansehen: http://localhost:8000
```

Veröffentlicht wird sie per GitHub Actions (`.github/workflows/pages.yml`) bei jeder Änderung in `docs/` auf `main`. Einmalig nötig: *Settings → Pages → Source: GitHub Actions*.

## Release

Ein Versions-Tag startet `.github/workflows/release.yml`: Der Workflow baut die App auf einem Mac-Runner für Apple-Chip und Intel, übernimmt die Version aus dem Tag und veröffentlicht `KeyboardBacklight.zip` als Release.

```bash
git tag v1.1 && git push origin v1.1
```
