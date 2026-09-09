import Foundation
import Testing
@testable import TrainingCalendar

struct BundledWorkoutFixtureSourceTests {
    @Test func decodesValidFixtureAndAssignsStableSortOrder() async throws {
        let url = try fixtureURL(contents: """
        [
          {"id":"a","name":"First","exerciseCount":1,"weekdayOffset":0,"initiallyCompleted":false},
          {"id":"b","name":"Second","exerciseCount":2,"weekdayOffset":0,"initiallyCompleted":true}
        ]
        """)

        let result = try await BundledWorkoutFixtureSource(url: url).load()

        #expect(result.map(\.id) == ["a", "b"])
        #expect(result.map(\.sortOrder) == [0, 1])
    }

    @Test func rejectsDuplicateIDs() async throws {
        let url = try fixtureURL(contents: """
        [
          {"id":"same","name":"First","exerciseCount":1,"weekdayOffset":0,"initiallyCompleted":false},
          {"id":"same","name":"Second","exerciseCount":2,"weekdayOffset":1,"initiallyCompleted":false}
        ]
        """)

        await #expect(throws: WorkoutFixtureError.duplicateID("same")) {
            try await BundledWorkoutFixtureSource(url: url).load()
        }
    }

    @Test func rejectsInvalidFields() async throws {
        let cases: [(String, WorkoutFixtureError)] = [
            (#"[{"id":" ","name":"Valid","exerciseCount":1,"weekdayOffset":0,"initiallyCompleted":false}]"#, .emptyID(0)),
            (#"[{"id":"a","name":" ","exerciseCount":1,"weekdayOffset":0,"initiallyCompleted":false}]"#, .emptyName("a")),
            (#"[{"id":"a","name":"Valid","exerciseCount":-1,"weekdayOffset":0,"initiallyCompleted":false}]"#, .negativeExerciseCount("a")),
            (#"[{"id":"a","name":"Valid","exerciseCount":1,"weekdayOffset":-1,"initiallyCompleted":false}]"#, .invalidWeekdayOffset("a")),
            (#"[{"id":"a","name":"Valid","exerciseCount":1,"weekdayOffset":7,"initiallyCompleted":false}]"#, .invalidWeekdayOffset("a"))
        ]
        for (json, expected) in cases {
            let url = try fixtureURL(contents: json)
            await #expect(throws: expected) { try await BundledWorkoutFixtureSource(url: url).load() }
        }
    }

    @Test func rejectsMalformedJSON() async throws {
        let url = try fixtureURL(contents: "not-json")
        await #expect(throws: DecodingError.self) {
            try await BundledWorkoutFixtureSource(url: url).load()
        }
    }

    @Test func unavailableSourceDefersResourceFailureUntilLoad() async {
        let source = UnavailableWorkoutFixtureSource(error: .missingResource("workouts.json"))

        await #expect(throws: WorkoutFixtureError.missingResource("workouts.json")) {
            try await source.load()
        }
    }

    private func fixtureURL(contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appendingPathExtension("json")
        try Data(contents.utf8).write(to: url)
        return url
    }
}
