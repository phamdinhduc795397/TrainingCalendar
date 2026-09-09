import Foundation

enum TrainingCalendarPhase: Equatable {
    case loading
    case loaded
    case initialError(String)
}

struct DayPresentation: Equatable, Identifiable {
    let id: Date
    let weekdayOffset: Int
    let date: Date
    let weekdayText: String
    let dayText: String
    let isToday: Bool
    let workouts: [WorkoutPresentation]
}

struct WorkoutPresentation: Equatable, Identifiable {
    let id: String
    let name: String
    let exerciseCountText: String
    let status: WorkoutDisplayStatus
    let statusText: String?
    let isCompleted: Bool
    let accessibilityLabel: String

    static let placeholder = WorkoutPresentation(
        id: "loading-placeholder",
        name: "Loading workout",
        exerciseCountText: "0 exercises",
        status: .future,
        statusText: nil,
        isCompleted: false,
        accessibilityLabel: "Loading workout"
    )
}
