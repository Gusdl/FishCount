# FishCount

Ein schlankes SwiftUI-MVP für manuelle und sprachgesteuerte Fischzählungen am Wasser. Die App setzt auf SwiftData (iOS 17+) und bietet eine Offline-first-Erfassung, Auswertung und Export der Daten.

## Highlights

- **Sprachaufnahme & Parser**: Deutscher Sprachsupport mit Voice-Kommandos ("Barsch bis 5 Zentimeter, drei Stück, Kommentar: Jungfische") inklusive `rückgängig` und Live-Feedback.
- **Manuelle Eingabe**: Schnellzugriff über glassmorphe Cards, Picker für Größenklassen sowie optionaler Kommentar.
- **Analyse**: Übersichten nach Art & Größenklasse, Balkendiagramm mit Swift Charts in einem aufgeräumten Dashboard.
- **Export**: CSV-/JSON-Export via Share-Sheet, temporäre Dateien werden automatisch entfernt.
- **Anpassung & Style**: Größenklassen-Verwaltung, kleiner Artkatalog mit Synonymen sowie ein maritim abgestimmtes UI mit hellem Dark-Mode-Look.

## Projektstruktur

```
FishCountApp/
├── FishCountApp.swift          // App-Einstieg & SwiftData-Konfiguration
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

1. `FishCountApp.xcodeproj` in Xcode 15 (oder neuer) öffnen.
2. Ziel-Schema `FishCountApp` auswählen.
3. Optional: In den Geräteeinstellungen des Simulators `Mikrofon` & `Spracherkennung` erlauben.
4. Auf einem iOS 17 Gerät oder Simulator ausführen.

## Continuous Integration

Ein GitHub Actions Workflow (`.github/workflows/ios-ci.yml`) baut das Projekt auf `macos-14` mit Xcode 15.4. Der Job führt `xcodebuild` gegen das geteilte Schema aus und deaktiviert Codesigning, so dass ein schneller Plausibilitäts-Check für Pull Requests entsteht.

## Assets & App Icon

Damit dieser Beispiel-Repo vollständig textbasiert bleibt, ist kein App-Icon-Bitmap enthalten. Xcode zeigt deshalb beim ersten Öffnen eine Warnung an. Für den Produktivbetrieb kannst du im Asset-Katalog (`FishCountApp/Resources/Assets.xcassets`) jederzeit ein eigenes Icon hinzufügen oder auf SF Symbols zurückgreifen.

## Roadmap-Ideen

- GPS-Koordinaten automatisch erfassen und als Metadata speichern.
- Erweiterte Artenbibliothek mit Fuzzy Matching.
- Synchronisation mit CloudKit für Multi-Device-Einsatz.
- Widgets für Schnellzugriff und Tagesübersichten.
