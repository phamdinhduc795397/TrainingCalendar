import Foundation

/// Loads the Everfit mock API. API assignment status `2` represents a completed
/// workout; statuses `0` and `1` are loaded as incomplete so local overrides
/// remain the single source of truth after the initial definition is cached.
struct RemoteWorkoutFixtureSource: WorkoutFixtureSource {
    static let productionURL = URL(string: "https://thinhleeverfit.github.io/everfit-ios-test-mock-api/workouts.json")!

    private let url: URL
    private let session: URLSession

    init(url: URL = Self.productionURL, session: URLSession = .shared) {
        self.url = url
        self.session = session
    }

    func load() async throws -> [WorkoutDefinition] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WorkoutFixtureError.invalidHTTPResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw WorkoutFixtureError.unacceptableHTTPStatusCode(httpResponse.statusCode)
        }
        return try Self.decodeDefinitions(from: data)
    }

    static func decodeDefinitions(from data: Data) throws -> [WorkoutDefinition] {
        let envelope = try JSONDecoder().decode(RemoteWorkoutEnvelopeDTO.self, from: data)
        var values: [WorkoutFixtureDTO] = []
        for day in envelope.data {
            guard (0...6).contains(day.day) else {
                throw WorkoutFixtureError.invalidRemoteDayOffset(day.day)
            }
            values.append(contentsOf: day.assignments.map {
                WorkoutFixtureDTO(
                    id: $0.id,
                    name: $0.title,
                    exerciseCount: $0.totalExercise,
                    weekdayOffset: day.day,
                    initiallyCompleted: $0.status == 2
                )
            })
        }
        return try WorkoutFixtureDecoder.definitions(from: values)
    }
}

private struct RemoteWorkoutEnvelopeDTO: Decodable {
    let data: [RemoteWorkoutDayDTO]
}

private struct RemoteWorkoutDayDTO: Decodable {
    let day: Int
    let assignments: [RemoteWorkoutAssignmentDTO]
}

private struct RemoteWorkoutAssignmentDTO: Decodable {
    let id: String
    let title: String
    let status: Int
    let totalExercise: Int

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title
        case status
        case totalExercise = "total_exercise"
    }
}
