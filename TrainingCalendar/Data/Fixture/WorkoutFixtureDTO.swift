import Foundation

struct WorkoutFixtureDTO: Decodable {
    let id: String
    let name: String
    let exerciseCount: Int
    let weekdayOffset: Int
    let initiallyCompleted: Bool
}

enum WorkoutFixtureError: Error, Equatable {
    case missingResource(String)
    case duplicateID(String)
    case emptyID(Int)
    case emptyName(String)
    case negativeExerciseCount(String)
    case invalidWeekdayOffset(String)
}

protocol WorkoutFixtureSource {
    func load() async throws -> [WorkoutDefinition]
}

/// Defers a setup-time fixture error until the normal asynchronous load path so
/// the app can still show its cached content and recovery UI.
struct UnavailableWorkoutFixtureSource: WorkoutFixtureSource {
    let error: WorkoutFixtureError

    func load() async throws -> [WorkoutDefinition] {
        throw error
    }
}
