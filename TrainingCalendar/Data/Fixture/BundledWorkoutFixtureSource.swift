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
        return try WorkoutFixtureDecoder.definitions(from: values)
    }
}
