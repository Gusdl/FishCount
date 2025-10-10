# Fischbestand

Ein schlankes SwiftUI-MVP für manuelle und sprachgesteuerte Fischzählungen am Wasser. Die App setzt auf SwiftData (iOS 17+) und bietet eine Offline-first-Erfassung, Auswertung und Export der Daten.

## Highlights

- **Sprachaufnahme & Parser**: Deutscher Sprachsupport mit Voice-Kommandos ("Barsch bis 5 Zentimeter, drei Stück, Kommentar: Jungfische") inklusive `rückgängig` und Live-Feedback.
- **Manuelle Eingabe**: Schnellzugriff über glassmorphe Cards, Picker für Größenklassen sowie optionaler Kommentar.
- **Analyse**: Übersichten nach Art & Größenklasse, Balkendiagramm mit Swift Charts in einem aufgeräumten Dashboard.
- **Export**: CSV-/JSON-Export via Share-Sheet, temporäre Dateien werden automatisch entfernt.
- **Anpassung & Style**: Größenklassen-Verwaltung, kleiner Artkatalog mit Synonymen sowie ein maritim abgestimmtes UI mit hellem Dark-Mode-Look.

## Projektstruktur

```
Fischbestand/
├── FischbestandApp.swift       // App-Einstieg & SwiftData-Konfiguration
├── Managers/
│   └── SpeechManager.swift     // Steuerung der Spracherkennung (de-DE)
├── Models/
│   └── Survey.swift            // SwiftData-Modelle (Survey, CountEntry, SizeClassPreset)
├── Services/
│   └── VoiceParser.swift       // Befehlserkennung & Parsing
├── Utilities/
│   ├── Exporters.swift         // CSV-/JSON-Erzeugung & Temp-Dateien
│   ├── ShareSheet.swift        // Wrapper für das iOS Share-Sheet
│   └── SpeciesCatalog.swift    // Artkatalog + Aliase
└── Views/
    ├── CaptureView.swift       // Erfassung mit Mic-Button, Info-Banner, Schnellzugriff
    ├── Components/
    │   ├── ManualEntrySheet.swift
    │   └── SurveyBreakdownChart.swift
    ├── ExportView.swift        // Share-Sheet-Export
    ├── SettingsView.swift      // Größenklassen-Verwaltung & App-Infos
    ├── SurveyDetailView.swift  // TabView aus Erfassung, Analyse, Export
    └── SurveyListView.swift    // NavigationStack + Survey-Liste
```

## Voraussetzungen

- Xcode 15 oder neuer
- iOS 17 SDK (SwiftData & Swift Charts)
- Aktivierte Berechtigungen in der `Info.plist`:
  - `NSSpeechRecognitionUsageDescription`
  - `NSMicrophoneUsageDescription`
  - Optional für GPS: `NSLocationWhenInUseUsageDescription`

## Erste Schritte

1. `Fischbestand.xcodeproj` in Xcode 15 (oder neuer) öffnen.
2. Ziel-Schema `Fischbestand` auswählen.
3. Optional: In den Geräteeinstellungen des Simulators `Mikrofon` & `Spracherkennung` erlauben.
4. Auf einem iOS 17 Gerät oder Simulator ausführen.

## Continuous Integration

Ein GitHub Actions Workflow (`.github/workflows/ios-ci.yml`) baut das Projekt auf `macos-14` mit Xcode 15.4. Der Job führt `xcodebuild` gegen das geteilte Schema aus und deaktiviert Codesigning, so dass ein schneller Plausibilitäts-Check für Pull Requests entsteht.

## Git & Merge-Tipps

- Die Datei `.gitattributes` erzwingt Text-Diffs für Swift- und Xcode-Projektdateien (`*.pbxproj`, `*.xcscheme` etc.). Dadurch werden sie nicht mehr als Binärdateien erkannt und Standard-Merge-Strategien wie `merge=union` greifen, so dass simple Konflikte automatisch aufgelöst werden.
- Sollte Xcode dennoch eine manuelle Auflösung fordern, hilft ein `git merge --abort` gefolgt von `git pull --rebase` sowie das erneute Öffnen des Projekts in Xcode. Dort können Konflikte im Projekt-Navigator bereinigt und anschließend über `git status` überprüft werden.
- Prüfe nach einem Merge mit `xcodebuild -resolvePackageDependencies` bzw. einem kurzen Build in Xcode, ob das Schema weiterhin kompilierbar ist.

## Assets & App Icon

Das App Icon wird bei jedem Build automatisch aus dem Skript `scripts/generate_fish_icons.py` erzeugt. Die generierten PNGs liegen deshalb **nicht** im Git-Repository, sondern werden während des Xcode-Builds (Run Script Phase) sowie in der CI-Pipeline frisch erstellt. Dadurch gibt es keine binären Änderungen mehr beim Pushen.

Wenn du ein anderes Motiv wünschst, passe das Skript an und führe anschließend `python scripts/generate_fish_icons.py` aus – die Icons landen wieder direkt im Asset-Katalog. Achte darauf, dass die erzeugten Bitmaps vollständig opak bleiben, damit App Store Connect den Upload akzeptiert.

## Roadmap-Ideen

- GPS-Koordinaten automatisch erfassen und als Metadata speichern.
- Erweiterte Artenbibliothek mit Fuzzy Matching.
- Synchronisation mit CloudKit für Multi-Device-Einsatz.
- Widgets für Schnellzugriff und Tagesübersichten.
