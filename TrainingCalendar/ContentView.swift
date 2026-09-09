//
//  ContentView.swift
//  TrainingCalendar
//
//  Created by Duc Pham on 8/9/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TrainingCalendarScreen(
            viewModel: TrainingCalendarViewModel(
                repository: SwiftDataWorkoutRepository(
                    context: modelContext,
                    source: bundledFixtureSource
                )
            )
        )
    }

    private var bundledFixtureSource: BundledWorkoutFixtureSource {
        do {
            return try BundledWorkoutFixtureSource()
        } catch {
            preconditionFailure("The bundled workouts.json fixture is required: \(error)")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [CachedWorkout.self, WorkoutCompletionOverride.self], inMemory: true)
}
