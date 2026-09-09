import Foundation

struct BundledWorkoutFixtureSource: WorkoutFixtureSource {
    private let url: URL

    init(url: URL) {
        self.url = url
    }

    init(bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: "workouts", withExtension: "json") else {
            throw WorkoutFixtureError.missingResource("workouts.json")
        }
        self.url = url
    }

    func load() async throws -> [WorkoutDefinition] {
        let data = try await Task.detached { try Data(contentsOf: url) }.value
        let values = try JSONDecoder().decode([WorkoutFixtureDTO].self, from: data)
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
