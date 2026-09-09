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
