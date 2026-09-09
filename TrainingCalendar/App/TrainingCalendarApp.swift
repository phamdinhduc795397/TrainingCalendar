import SwiftData
import SwiftUI

@main
struct TrainingCalendarApp: App {
    private let container: ModelContainer
    private let viewModel: TrainingCalendarViewModel

    init() {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
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

        let source: any WorkoutFixtureSource
        do {
            source = try BundledWorkoutFixtureSource(bundle: .main)
        } catch {
            source = UnavailableWorkoutFixtureSource(error: .missingResource("workouts.json"))
        }
        if isUITesting && ProcessInfo.processInfo.arguments.contains("-reset-store") {
            try? modelContainer.mainContext.delete(model: CachedWorkout.self)
            try? modelContainer.mainContext.delete(model: WorkoutCompletionOverride.self)
            try? modelContainer.mainContext.save()
        }
        let now: () -> Date = isUITesting ? { Self.uiTestDate } : { Date() }
        let calendar = isUITesting ? Self.uiTestCalendar : Calendar.current
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

    private static let uiTestDate: Date = {
        uiTestCalendar.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 12))!
    }()

    private static var uiTestCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }
}
