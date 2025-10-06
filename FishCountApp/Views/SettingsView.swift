import SwiftUI
import SwiftData

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Voreinstellungen")) {
                    NavigationLink("Größenklassen verwalten") {
                        SizeClassManagementView()
                    }
                }

                Section(header: Text("Über")) {
                    Label("Offline-first Sprachzählung", systemImage: "waveform")
                    Label("Version 0.1", systemImage: "info.circle")
                }
            }
            .navigationTitle("Einstellungen")
        }
    }
}

private struct SizeClassManagementView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SizeClassPreset.label) private var sizeClasses: [SizeClassPreset]
    @State private var label: String = ""
    @State private var lowerBound: String = ""
    @State private var upperBound: String = ""
    @State private var didLoadDefaults = false

    var body: some View {
        List {
            Section(header: Text("Bestehende Klassen")) {
                if sizeClasses.isEmpty {
                    ContentUnavailableView("Keine Klassen", systemImage: "ruler",
                                           description: Text("Füge deine ersten Größenklassen hinzu."))
                } else {
                    ForEach(sizeClasses) { preset in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.label)
                                .font(.headline)
                            Text(boundsText(for: preset))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { indexSet in
                        indexSet.map { sizeClasses[$0] }.forEach(context.delete)
                        try? context.save()
                    }
                }
            }

            Section(header: Text("Neue Klasse")) {
                TextField("Bezeichnung", text: $label)
                HStack {
                    TextField("ab", text: $lowerBound)
                        .keyboardType(.numberPad)
                    Text("bis")
                    TextField("bis", text: $upperBound)
                        .keyboardType(.numberPad)
                }
                Button("Hinzufügen") {
                    addPreset()
                }
                .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("Größenklassen")
        .toolbar { EditButton() }
        .task {
            await ensureDefaultSizeClasses()
        }
    }

    private func addPreset() {
        let lower = Int(lowerBound)
        let upper = Int(upperBound)
        let preset = SizeClassPreset(label: label, lowerBound: lower, upperBound: upper, isDefault: false)
        context.insert(preset)
        try? context.save()
        label = ""
        lowerBound = ""
        upperBound = ""
    }

    private func ensureDefaultSizeClasses() async {
        guard !didLoadDefaults else { return }
        if sizeClasses.isEmpty {
            let defaults: [SizeClassPreset] = [
                SizeClassPreset(label: "0–5 cm", lowerBound: 0, upperBound: 5, isDefault: true),
                SizeClassPreset(label: "6–10 cm", lowerBound: 6, upperBound: 10, isDefault: true),
                SizeClassPreset(label: "11–15 cm", lowerBound: 11, upperBound: 15, isDefault: true),
                SizeClassPreset(label: "16–20 cm", lowerBound: 16, upperBound: 20, isDefault: true)
            ]
            defaults.forEach(context.insert)
            try? context.save()
        }
        didLoadDefaults = true
    }

    private func boundsText(for preset: SizeClassPreset) -> String {
        switch (preset.lowerBound, preset.upperBound) {
        case let (low?, high?):
            return "\(low) – \(high) cm"
        case let (low?, nil):
            return "ab \(low) cm"
        case let (nil, high?):
            return "bis \(high) cm"
        default:
            return "Freier Text"
        }
    }
}
