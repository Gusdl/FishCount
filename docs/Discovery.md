# Product Discovery – Fischbestand

## 1. Product Snapshot
- **Vision**: A lightweight SwiftUI MVP that enables anglers to capture fish counts hands-free or manually, store them offline with SwiftData, and export results for further processing.【F:README.md†L3-L12】
- **Primary users**: Field biologists, angling clubs, and citizen science volunteers who need structured, fast, and reliable catch logging in environments with poor connectivity.
- **Core value props**:
  - Voice-driven logging with German commands, undo, and contextual hints reduces friction when handling gear by the water.【F:Fischbestand/Views/CaptureView.swift†L175-L233】【F:Fischbestand/Services/VoiceParser.swift†L44-L140】
  - Manual quick-entry UI, size-class presets, and featured species speed up repeat recording tasks.【F:Fischbestand/Views/CaptureView.swift†L243-L322】【F:Fischbestand/Utilities/SpeciesCatalog.swift†L3-L29】
  - Integrated analysis, export, and location metadata keep workflows in one app and ready for sharing.【F:Fischbestand/Views/SurveyDetailView.swift†L28-L117】【F:Fischbestand/Views/ExportView.swift†L21-L85】【F:Fischbestand/Managers/LocationManager.swift†L5-L93】

## 2. Current Experience Audit
| Journey Step | Observations |
| --- | --- |
| Landing & sessions | Home list highlights cumulative metrics, sessions, and empty states; users can add surveys and access settings from the navigation bar.【F:Fischbestand/Views/SurveyListView.swift†L12-L108】 |
| Capture | Capture tab combines header metadata, voice recording controls, manual undo, quick species shortcuts, and entry history with context-aware hints for speech recognition.【F:Fischbestand/Views/CaptureView.swift†L37-L398】 |
| Analysis | Tabbed detail view shows charts and grouped breakdowns once entries exist, keeping the capture-analysis-export flow tightly integrated.【F:Fischbestand/Views/SurveyDetailView.swift†L11-L117】 |
| Export | CSV/JSON share-sheet export and auto-cleanup support downstream reporting without leaving the app.【F:Fischbestand/Views/ExportView.swift†L21-L85】 |
| Configuration | Settings exposes size-class management with default seeding, but little else about survey metadata or personalization.【F:Fischbestand/Views/SettingsView.swift†L4-L127】 |
| Data foundations | Survey model already stores geolocation, weather notes, and entries with comments/timestamps, although some fields are unused in the UI.【F:Fischbestand/Models/Survey.swift†L4-L52】 |

## 3. Gaps & Opportunities
### Product & UX
- **Weather capture loop was missing**: Users can now open a quick-edit sheet from the capture header to add or update contextual notes; consider structured fields (temperature, flow) next.【F:Fischbestand/Views/CaptureView.swift†L44-L154】
- **Location feedback lacks clarity**: Errors surface via alerts, but there is no persistent status indicator or map snippet to reassure users when GPS is unavailable. Status badges were added to the capture header; consider a mini-map or accuracy readout next.【F:Fischbestand/Views/CaptureView.swift†L98-L152】【F:Fischbestand/Managers/LocationManager.swift†L5-L93】
- **Limited taxonomy depth**: Species catalog features 14 species plus aliases; clubs may need regional variants, invasive species, or saltwater data, requiring extensibility tools (import, tagging).【F:Fischbestand/Utilities/SpeciesCatalog.swift†L3-L29】
- **No onboarding or tutorial**: Voice syntax is implied by placeholder text; a first-run walkthrough or command cheat-sheet would reduce the learning curve.【F:Fischbestand/Views/CaptureView.swift†L150-L169】
- **Collaboration gaps**: Surveys are single-user and device-local; teams cannot merge logs or share sessions without manual exports.【F:Fischbestand/Views/ExportView.swift†L21-L85】

### Technical & Data
- **Offline scope stops at device**: There is no sync, backup, or cross-device access despite model support for metadata; consider CloudKit or simple file export automation.【F:Fischbestand/Models/Survey.swift†L8-L18】
- **Testing & automation**: Project lacks unit/UI tests around parsing, speech, and exports—key for reliability in noisy field conditions.
- **Speech robustness**: Parser relies on a static species list and regex heuristics; background noise, pluralization, and measurement variants beyond centimeters could cause misses.【F:Fischbestand/Services/VoiceParser.swift†L44-L140】
- **Accessibility**: Voice-first approach is strong, but manual flows lack Dynamic Type scaling, VoiceOver hints, or haptic confirmations.

### Business & Monetization
- **Value packaging undefined**: There is no pricing, feature gating, or plan differentiation (e.g., free logging vs. premium analytics for clubs).
- **Data ownership messaging**: Offline-first is a selling point but needs explicit communication on privacy and data portability (especially for government-funded surveys).

## 4. Suggested Next Steps
### Short-term (MVP polish)
1. ✅ Add editable weather & water conditions fields in capture settings or a quick note prompt to unlock context already modeled (implemented via capture header quick-edit).【F:Fischbestand/Views/CaptureView.swift†L44-L154】
2. Expand species management with CSV import, tagging, and user-defined shortcuts to cover diverse fisheries.【F:Fischbestand/Utilities/SpeciesCatalog.swift†L3-L29】
3. Implement lightweight onboarding: first-run checklist, sample voice command list, and fallback instructions in case of speech failure.【F:Fischbestand/Views/CaptureView.swift†L150-L198】
4. Instrument crash/log capture around speech permissions and location errors for faster support triage.【F:Fischbestand/Views/CaptureView.swift†L175-L233】【F:Fischbestand/Managers/LocationManager.swift†L60-L95】

### Mid-term (v1 release)
- Build aggregated dashboards (per species trends, heatmaps) leveraging stored timestamps and coordinates once location reliability improves.【F:Fischbestand/Models/Survey.swift†L8-L28】【F:Fischbestand/Views/SurveyDetailView.swift†L59-L117】
- Offer survey templates (preset species lists, count defaults) for recurring monitoring programs.【F:Fischbestand/Views/SettingsView.swift†L26-L127】
- Explore optional CloudKit sync or collaborative exports for clubs needing centralized archives.

### Long-term (growth bets)
- Integrate regulatory exports (e.g., fisheries authorities formats) and automation APIs for research partners.【F:Fischbestand/Views/ExportView.swift†L21-L85】
- Investigate passive data capture (BLE scales, camera recognition) once core workflows are stable.
- Consider marketplace positioning as a toolkit for conservation NGOs, bundling analytics subscriptions and training resources.

## 5. Marketing Narrative & GTM
- **Positioning**: “Fischbestand – die Offline-Sprach-App für präzise Fangstatistiken vor Ort.” Emphasize hands-free capture, offline reliability, and structured exports for compliance.【F:README.md†L3-L12】
- **Messaging pillars**: (1) Hands-free logging with German voice control; (2) Instant insights via on-device charts; (3) Data ownership through offline-first design.【F:Fischbestand/Views/CaptureView.swift†L175-L344】【F:Fischbestand/Views/SurveyDetailView.swift†L28-L117】【F:Fischbestand/Views/ExportView.swift†L21-L85】
- **Channels**: Target angling federations, citizen science forums, and conservation agencies via webinars, field demos, and App Store feature pitches highlighting sustainability impact.
- **Proof & retention**: Publish case studies demonstrating time saved in manual surveys, track weekly active surveyors, export frequency, and voice-command success rate as key health metrics.
- **Expansion hooks**: Offer branded exports or co-op marketing with gear manufacturers to reach hobby anglers once professional credibility is established.
