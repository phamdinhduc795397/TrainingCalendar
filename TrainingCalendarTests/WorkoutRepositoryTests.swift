import Foundation
import SwiftData
import Testing
@testable import TrainingCalendar

@MainActor
struct WorkoutRepositoryTests {
    @Test func refreshPreservesExplicitFalseOverride() async throws {
        let fixture = StubFixtureSource(definitions: [definition(id: "a", initiallyCompleted: true)])
        let harness = try makeRepository(source: fixture)
        let repository = harness.repository
        _ = try await repository.refresh()
        _ = try await repository.toggleCompletion(workoutID: "a")

        let refreshed = try await repository.refresh()

        #expect(refreshed.effectiveCompletion(for: "a") == false)
        #expect(refreshed.completionOverrides["a"] == false)
    }

    @Test func cachedSnapshotSurvivesRepositoryRecreation() async throws {
        let container = try makeContainer()
        let first = SwiftDataWorkoutRepository(
            context: container.mainContext,
            source: StubFixtureSource(definitions: [definition(id: "a")])
        )
        _ = try await first.refresh()
        _ = try await first.toggleCompletion(workoutID: "a")

        let second = SwiftDataWorkoutRepository(
            context: container.mainContext,
            source: StubFixtureSource(definitions: [])
        )
        let cached = try await second.cachedSnapshot()

        #expect(cached.definitions.map(\.id) == ["a"])
        #expect(cached.effectiveCompletion(for: "a") == true)
    }

    @Test func refreshSortsDefinitionsAndRemovesStaleData() async throws {
        let source = SequenceFixtureSource(responses: [
            [definition(id: "old"), definition(id: "kept", sortOrder: 1)],
            [definition(id: "new", sortOrder: 1), definition(id: "kept", sortOrder: 0)]
        ])
        let harness = try makeRepository(source: source)
        let repository = harness.repository
        _ = try await repository.refresh()
        _ = try await repository.toggleCompletion(workoutID: "old")

        let result = try await repository.refresh()

        #expect(result.definitions.map(\.id) == ["kept", "new"])
        #expect(result.completionOverrides["old"] == nil)
    }

    @Test func unknownToggleThrows() async throws {
        let harness = try makeRepository(source: StubFixtureSource(definitions: []))
        let repository = harness.repository

        await #expect(throws: WorkoutRepositoryError.workoutNotFound("missing")) {
            try await repository.toggleCompletion(workoutID: "missing")
        }
    }

    @Test func failedRefreshLeavesCachedSnapshotUnchanged() async throws {
        let container = try makeContainer()
        let initial = SwiftDataWorkoutRepository(
            context: container.mainContext,
            source: StubFixtureSource(definitions: [definition(id: "cached", initiallyCompleted: true)])
        )
        let expected = try await initial.refresh()
        let failing = SwiftDataWorkoutRepository(context: container.mainContext, source: FailingFixtureSource())

        await #expect(throws: FixtureFailure.self) {
            try await failing.refresh()
        }
        let cached = try await failing.cachedSnapshot()

        #expect(cached == expected)
    }
}

private struct StubFixtureSource: WorkoutFixtureSource {
    let definitions: [WorkoutDefinition]

    func load() async throws -> [WorkoutDefinition] { definitions }
}

@MainActor
private final class SequenceFixtureSource: WorkoutFixtureSource {
    private var responses: [[WorkoutDefinition]]

    init(responses: [[WorkoutDefinition]]) {
        self.responses = responses
    }

    func load() async throws -> [WorkoutDefinition] {
        responses.removeFirst()
    }
}

private struct FailingFixtureSource: WorkoutFixtureSource {
    func load() async throws -> [WorkoutDefinition] {
        throw FixtureFailure()
    }
}

private struct FixtureFailure: Error {}

@MainActor
private func makeContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: CachedWorkout.self,
        WorkoutCompletionOverride.self,
        configurations: configuration
    )
}

@MainActor
private final class RepositoryHarness {
    let container: ModelContainer
    let repository: SwiftDataWorkoutRepository

    init(container: ModelContainer, source: any WorkoutFixtureSource) {
        self.container = container
        repository = SwiftDataWorkoutRepository(
            context: container.mainContext,
            source: source,
            now: { Date(timeIntervalSince1970: 1) }
        )
    }
}

@MainActor
private func makeRepository(source: any WorkoutFixtureSource) throws -> RepositoryHarness {
    let container = try makeContainer()
    return RepositoryHarness(container: container, source: source)
}

private func definition(
    id: String,
    initiallyCompleted: Bool = false,
    sortOrder: Int = 0
) -> WorkoutDefinition {
    WorkoutDefinition(
        id: id,
        name: id,
        exerciseCount: 1,
        weekdayOffset: 0,
        initiallyCompleted: initiallyCompleted,
        sortOrder: sortOrder
    )
}
