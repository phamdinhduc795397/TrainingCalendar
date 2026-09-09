import Foundation
import Testing
@testable import TrainingCalendar

@MainActor
struct RemoteWorkoutFixtureSourceTests {
    @Test func decodesEnvelopeFlattensAssignmentsAndMapsCompletionStatus() throws {
        let data = Data("""
        {
          "data": [
            {"_id":"day-0","day":0,"assignments":[
              {"_id":"a","title":"Warm up","status":1,"total_exercise":2},
              {"_id":"b","title":"Strength","status":2,"total_exercise":5}
            ]},
            {"_id":"day-4","day":4,"assignments":[
              {"_id":"c","title":"Intervals","status":0,"total_exercise":8}
            ]}
          ]
        }
        """.utf8)

        let definitions = try RemoteWorkoutFixtureSource.decodeDefinitions(from: data)

        #expect(definitions.map(\.id) == ["a", "b", "c"])
        #expect(definitions.map(\.weekdayOffset) == [0, 0, 4])
        #expect(definitions.map(\.sortOrder) == [0, 1, 2])
        #expect(definitions.map(\.initiallyCompleted) == [false, true, false])
    }

    @Test func rejectsInvalidRemoteDayEvenWhenItHasNoAssignments() throws {
        let data = Data(#"{"data":[{"_id":"day-7","day":7,"assignments":[]}]}"#.utf8)

        #expect(throws: WorkoutFixtureError.invalidRemoteDayOffset(7)) {
            try RemoteWorkoutFixtureSource.decodeDefinitions(from: data)
        }
    }

    @Test func rejectsInvalidAssignmentFieldsAfterMapping() throws {
        let data = Data(#"{"data":[{"_id":"day-0","day":0,"assignments":[{"_id":"a","title":"Workout","status":0,"total_exercise":-1}]}]}"#.utf8)

        #expect(throws: WorkoutFixtureError.negativeExerciseCount("a")) {
            try RemoteWorkoutFixtureSource.decodeDefinitions(from: data)
        }
    }

    @Test func rejectsNonSuccessHTTPResponse() async {
        MockURLProtocol.responseData = Data(#"{"data":[]}"#.utf8)
        let source = RemoteWorkoutFixtureSource(
            url: URL(string: "https://example.test/workouts.json")!,
            session: makeSession(responseStatusCode: 503)
        )

        await #expect(throws: WorkoutFixtureError.unacceptableHTTPStatusCode(503)) {
            try await source.load()
        }
    }
    private func makeSession(responseStatusCode: Int) -> URLSession {
        MockURLProtocol.statusCode = responseStatusCode
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseData = Data()
    nonisolated(unsafe) static var statusCode = 200

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
