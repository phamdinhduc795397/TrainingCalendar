import Foundation
import Testing
@testable import TrainingCalendar

@MainActor
struct TrainingCalendarViewModelTests {
    @Test func exposesDatesBeforeSuspendedRefreshAndThenGroupsMultipleWorkouts() async throws {
        let repository = ControlledRepository(cached: .empty)
        let viewModel = makeViewModel(repository: repository)

        let task = Task { await viewModel.load() }
        await repository.waitUntilRefreshStarts()

        #expect(viewModel.days.count == 7)
        #expect(viewModel.phase == .loading)

        repository.finishRefresh(with: snapshot(offsets: [0, 0, 2]))
        await task.value
        #expect(viewModel.days[0].workouts.count == 2)
        #expect(viewModel.days[2].workouts.count == 1)
        #expect(viewModel.phase == .loaded)
    }

    @Test func cachedContentRemainsVisibleWhenRefreshFails() async {
        let repository = FailingRefreshRepository(cached: snapshot(offsets: [1]))
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()

        #expect(viewModel.days[1].workouts.count == 1)
        #expect(viewModel.phase == .loaded)
        #expect(viewModel.refreshErrorMessage != nil)
    }

    @Test func toggleUsesWorkoutIDAndPublishesPersistedResult() async {
        let repository = RecordingRepository(snapshot: snapshot(offsets: [5]))
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()

        await viewModel.toggleCompletion(workoutID: "workout-0")

        #expect(repository.toggledIDs == ["workout-0"])
        #expect(viewModel.days[5].workouts[0].status == .completed)
    }

    @Test func preservesLongNameAndFormatsExerciseCounts() async {
        let longName = "Weekend Endurance and Conditioning Session"
        let definitions = [
            WorkoutDefinition(id: "one", name: longName, exerciseCount: 1, weekdayOffset: 5, initiallyCompleted: false, sortOrder: 0),
            WorkoutDefinition(id: "many", name: "Strength", exerciseCount: 12, weekdayOffset: 5, initiallyCompleted: false, sortOrder: 1)
        ]
        let repository = RecordingRepository(snapshot: WorkoutSnapshot(definitions: definitions, completionOverrides: [:]))
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()

        #expect(viewModel.days[5].workouts[0].name == longName)
        #expect(viewModel.days[5].workouts[0].exerciseCountText == "1 exercise")
        #expect(viewModel.days[5].workouts[1].exerciseCountText == "12 exercises")
        #expect(viewModel.days[5].workouts[0].statusText == nil)
    }

    @Test func exposesInitialErrorWhileKeepingSevenDates() async {
        let viewModel = makeViewModel(repository: FailingRefreshRepository(cached: .empty))

        await viewModel.load()

        #expect(viewModel.days.count == 7)
        #expect(viewModel.phase == .initialError("Unable to load workouts."))
    }
}

@MainActor
private final class ControlledRepository: WorkoutRepositoryProtocol {
    private let cached: WorkoutSnapshot
    private var refreshStarted = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var refreshContinuation: CheckedContinuation<WorkoutSnapshot, Error>?

    init(cached: WorkoutSnapshot) { self.cached = cached }
    func cachedSnapshot() async throws -> WorkoutSnapshot { cached }
    func refresh() async throws -> WorkoutSnapshot {
        refreshStarted = true
        startWaiters.forEach { $0.resume() }
        startWaiters.removeAll()
        return try await withCheckedThrowingContinuation { refreshContinuation = $0 }
    }
    func toggleCompletion(workoutID: String) async throws -> WorkoutSnapshot { cached }
    func waitUntilRefreshStarts() async {
        if refreshStarted { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }
    func finishRefresh(with snapshot: WorkoutSnapshot) { refreshContinuation?.resume(returning: snapshot) }
}

private enum TestFailure: Error { case refresh }

@MainActor
private final class FailingRefreshRepository: WorkoutRepositoryProtocol {
    private let cached: WorkoutSnapshot
    init(cached: WorkoutSnapshot) { self.cached = cached }
    func cachedSnapshot() async throws -> WorkoutSnapshot { cached }
    func refresh() async throws -> WorkoutSnapshot { throw TestFailure.refresh }
    func toggleCompletion(workoutID: String) async throws -> WorkoutSnapshot { cached }
}

@MainActor
private final class RecordingRepository: WorkoutRepositoryProtocol {
    private var snapshotValue: WorkoutSnapshot
    private(set) var toggledIDs: [String] = []
    init(snapshot: WorkoutSnapshot) { snapshotValue = snapshot }
    func cachedSnapshot() async throws -> WorkoutSnapshot { snapshotValue }
    func refresh() async throws -> WorkoutSnapshot { snapshotValue }
    func toggleCompletion(workoutID: String) async throws -> WorkoutSnapshot {
        toggledIDs.append(workoutID)
        var overrides = snapshotValue.completionOverrides
        overrides[workoutID] = !snapshotValue.effectiveCompletion(for: workoutID)
        snapshotValue = WorkoutSnapshot(definitions: snapshotValue.definitions, completionOverrides: overrides)
        return snapshotValue
    }
}

@MainActor
private func makeViewModel(repository: any WorkoutRepositoryProtocol) -> TrainingCalendarViewModel {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 12))!
    return TrainingCalendarViewModel(repository: repository, calendar: calendar, now: { now })
}

@MainActor
private func snapshot(offsets: [Int]) -> WorkoutSnapshot {
    let definitions = offsets.enumerated().map { index, offset in
        WorkoutDefinition(id: "workout-\(index)", name: "Workout \(index)", exerciseCount: index == 0 ? 1 : 2, weekdayOffset: offset, initiallyCompleted: false, sortOrder: index)
    }
    return WorkoutSnapshot(definitions: definitions, completionOverrides: [:])
}
