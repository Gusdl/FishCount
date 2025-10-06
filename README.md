# FishCount

Ein schlankes SwiftUI-MVP für manuelle und sprachgesteuerte Fischzählungen am Wasser. Die App setzt auf SwiftData (iOS 17+) und bietet eine Offline-first-Erfassung, Auswertung und Export der Daten.

## Highlights

- **Sprachaufnahme & Parser**: Deutscher Sprachsupport mit Voice-Kommandos ("Barsch bis 5 Zentimeter, drei Stück, Kommentar: Jungfische") inklusive `rückgängig`.
- **Manuelle Eingabe**: Schnellzugriff über Buttons, Picker für Größenklassen sowie optionaler Kommentar.
- **Analyse**: Übersichten nach Art & Größenklasse, Balkendiagramm mit Swift Charts.
- **Export**: CSV-/JSON-Export via Share-Sheet, temporäre Dateien werden automatisch entfernt.
- **Anpassung**: Größenklassen-Verwaltung, kleiner Artkatalog mit Synonymen.

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

1. Projektordner in Xcode öffnen (`FishCountApp` als neues SwiftUI-App-Projekt verwenden oder bestehenden Projektquellcode integrieren).
2. SwiftData-Persistenz aktivieren (Xcode generiert automatisch das Model-Container-Setup).
3. Berechtigungs-Strings in der `Info.plist` ergänzen.
4. Auf einem iOS 17 Gerät oder Simulator ausführen.

## Roadmap-Ideen

- GPS-Koordinaten automatisch erfassen und als Metadata speichern.
- Erweiterte Artenbibliothek mit Fuzzy Matching.
- Synchronisation mit CloudKit für Multi-Device-Einsatz.
- Widgets für Schnellzugriff und Tagesübersichten.
