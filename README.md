# KeyboardBacklight

Menüleisten-App für macOS, die die Tastaturbeleuchtung wieder per Taste steuert – wie früher:

- **🌙 Mond-Taste (F6)** → dunkler
- **◀◀ Zurück-Taste (F7)** → heller
- 16 Stufen, mit ⌥⇧ feinere Schritte
- Einblendung mit Helligkeitsbalken, Menüleisten-Icon im Stil des alten macOS-Symbols
- Tasten frei belegbar, Icon ausblendbar, Autostart beim Anmelden

Getestet auf MacBook Air M3 mit macOS 26.

## Bauen

Benötigt nur die Xcode Command Line Tools.

```bash
./build.sh           # baut KeyboardBacklight.app im Projektordner
./build.sh install   # zusätzlich nach /Applications installieren und starten
```

Beim ersten Start fragt macOS nach dem **Bedienungshilfen-Zugriff** – ohne ihn können die Tasten nicht abgefangen werden.

## Technik

- Helligkeit über das private Framework `CoreBrightness` (`KeyboardBrightnessClient`)
- Tasten über einen `CGEventTap` (Mond-Taste = Tastencode 178, Zurück = Media-Key `NX_KEYTYPE_REWIND`)
- Bei hellem Umgebungslicht hält die Helligkeitsautomatik die Beleuchtung aus; sie wird deshalb beim ersten Tastendruck abgeschaltet (im Menü wieder aktivierbar)
- App-Icon: `swift Scripts/make-icon.swift`
