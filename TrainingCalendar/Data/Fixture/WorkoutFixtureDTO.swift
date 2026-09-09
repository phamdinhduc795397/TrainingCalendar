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
    case invalidRemoteDayOffset(Int)
    case invalidHTTPResponse
    case unacceptableHTTPStatusCode(Int)
}

enum WorkoutFixtureDecoder {
    static func definitions(from values: [WorkoutFixtureDTO]) throws -> [WorkoutDefinition] {
        var seen = Set<String>()
        return try values.enumerated().map { index, value in
            let id = value.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty else { throw WorkoutFixtureError.emptyID(index) }
            guard seen.insert(id).inserted else { throw WorkoutFixtureError.duplicateID(id) }
            guard !value.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw WorkoutFixtureError.emptyName(id)
            }
            guard value.exerciseCount >= 0 else { throw WorkoutFixtureError.negativeExerciseCount(id) }
            guard (0...6).contains(value.weekdayOffset) else { throw WorkoutFixtureError.invalidWeekdayOffset(id) }
            return WorkoutDefinition(
                id: id,
                name: value.name,
                exerciseCount: value.exerciseCount,
                weekdayOffset: value.weekdayOffset,
                initiallyCompleted: value.initiallyCompleted,
                sortOrder: index
            )
        }
    }
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
