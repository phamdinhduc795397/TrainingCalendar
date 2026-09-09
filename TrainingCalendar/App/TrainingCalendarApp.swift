import SwiftData
import SwiftUI

@main
struct TrainingCalendarApp: App {
    private let container: ModelContainer
    private let viewModel: TrainingCalendarViewModel

    init() {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: false)
        let modelContainer: ModelContainer
        do {
            modelContainer = try ModelContainer(
                for: CachedWorkout.self,
                WorkoutCompletionOverride.self,
                configurations: configuration
            )
        } catch {
            fatalError("Unable to configure Training Calendar: \(error)")
        }

        let source: any WorkoutFixtureSource = RemoteWorkoutFixtureSource()
        let now: () -> Date = { Date() }
        let calendar = Calendar.current
        let repository = SwiftDataWorkoutRepository(context: modelContainer.mainContext, source: source, now: now)
        container = modelContainer
        viewModel = TrainingCalendarViewModel(repository: repository, calendar: calendar, now: now)
    }

    var body: some Scene {
        WindowGroup {
            TrainingCalendarScreen(viewModel: viewModel)
        }
        .modelContainer(container)
    }
}
