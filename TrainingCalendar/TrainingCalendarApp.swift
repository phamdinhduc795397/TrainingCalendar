//
//  TrainingCalendarApp.swift
//  TrainingCalendar
//
//  Created by Duc Pham on 8/9/26.
//

import SwiftUI
import SwiftData

@main
struct TrainingCalendarApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CachedWorkout.self,
            WorkoutCompletionOverride.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
