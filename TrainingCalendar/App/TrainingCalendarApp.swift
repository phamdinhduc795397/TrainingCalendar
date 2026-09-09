import SwiftData
import SwiftUI

@main
struct TrainingCalendarApp: App {
    private let container: ModelContainer
    private let viewModel: TrainingCalendarViewModel

    init() {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        let configuration = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            let modelContainer = try ModelContainer(
                for: CachedWorkout.self,
                WorkoutCompletionOverride.self,
                configurations: configuration
            )
            let source = try BundledWorkoutFixtureSource(bundle: .main)
            let repository = SwiftDataWorkoutRepository(context: modelContainer.mainContext, source: source)
            if isUITesting && ProcessInfo.processInfo.arguments.contains("-reset-store") {
                try modelContainer.mainContext.delete(model: CachedWorkout.self)
                try modelContainer.mainContext.delete(model: WorkoutCompletionOverride.self)
                try modelContainer.mainContext.save()
            }
            container = modelContainer
            viewModel = TrainingCalendarViewModel(repository: repository)
        } catch {
            fatalError("Unable to configure Training Calendar: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            TrainingCalendarScreen(viewModel: viewModel)
        }
        .modelContainer(container)
    }
}
