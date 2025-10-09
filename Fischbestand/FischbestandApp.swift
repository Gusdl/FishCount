import SwiftUI
import SwiftData

@main
struct FischbestandApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Survey.self,
            CountEntry.self,
            SizeClassPreset.self
        ])

        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("Failed to create model container: \(error.localizedDescription)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            SurveyListView()
                .modelContainer(sharedModelContainer)
        }
    }
}
