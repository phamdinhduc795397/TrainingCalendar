import Foundation
import Observation

@Observable
@MainActor
final class TrainingCalendarViewModel {
    private(set) var days: [DayPresentation] = []
    private(set) var phase: TrainingCalendarPhase = .loading
    private(set) var isRefreshing = false
    private(set) var refreshErrorMessage: String?

    private let repository: any WorkoutRepositoryProtocol
    private let calendar: Calendar
    private let now: () -> Date
    private var loadTask: Task<Void, Never>?

    init(repository: any WorkoutRepositoryProtocol, calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.calendar = calendar
        self.now = now
        days = makeDays(snapshot: .empty)
    }

    func load() async {
        if let loadTask { await loadTask.value; return }
        let task = Task { await performInitialLoad() }
        loadTask = task
        await task.value
        loadTask = nil
    }

    func retry() async { await refresh(hasVisibleContent: days.contains { !$0.workouts.isEmpty }) }

    func toggleCompletion(workoutID: String) async {
        do {
            let snapshot = try await repository.toggleCompletion(workoutID: workoutID)
            days = makeDays(snapshot: snapshot)
        } catch {
            refreshErrorMessage = "Unable to save completion. Please try again."
        }
    }

    private func performInitialLoad() async {
        days = makeDays(snapshot: .empty)
        phase = .loading
        var hasVisibleContent = false
        do {
            let cached = try await repository.cachedSnapshot()
            if !cached.definitions.isEmpty {
                days = makeDays(snapshot: cached)
                phase = .loaded
                hasVisibleContent = true
            }
        } catch {
            // Refresh below is the recovery path for an unreadable cache.
        }
        await refresh(hasVisibleContent: hasVisibleContent)
    }

    private func refresh(hasVisibleContent: Bool) async {
        isRefreshing = hasVisibleContent
        defer { isRefreshing = false }
        do {
            let refreshed = try await repository.refresh()
            days = makeDays(snapshot: refreshed)
            phase = .loaded
            refreshErrorMessage = nil
        } catch {
            if hasVisibleContent {
                phase = .loaded
                refreshErrorMessage = "Unable to refresh workouts."
            } else {
                phase = .initialError("Unable to load workouts.")
            }
        }
    }

    private func makeDays(snapshot: WorkoutSnapshot) -> [DayPresentation] {
        let currentDate = now()
        guard let week = try? CurrentWeekBuilder.days(containing: currentDate, calendar: calendar) else { return [] }
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.calendar = calendar
        weekdayFormatter.locale = calendar.locale ?? .current
        weekdayFormatter.dateFormat = "EEE"
        let dayFormatter = DateFormatter()
        dayFormatter.calendar = calendar
        dayFormatter.locale = calendar.locale ?? .current
        dayFormatter.dateFormat = "d"

        return week.enumerated().map { offset, date in
            let workouts = snapshot.definitions
                .filter { $0.weekdayOffset == offset }
                .sorted { $0.sortOrder < $1.sortOrder }
                .map { definition in
                    let completed = snapshot.effectiveCompletion(for: definition.id)
                    let status = WorkoutStatusResolver.resolve(scheduledDate: date, today: currentDate, isCompleted: completed, calendar: calendar)
                    let countText = definition.exerciseCount == 1 ? "1 exercise" : "\(definition.exerciseCount) exercises"
                    let statusText = status.label
                    let accessibility = [definition.name, countText, statusText].compactMap { $0 }.joined(separator: ", ")
                    return WorkoutPresentation(id: definition.id, name: definition.name, exerciseCountText: countText, status: status, statusText: statusText, isCompleted: completed, accessibilityLabel: accessibility)
                }
            return DayPresentation(
                id: date,
                weekdayOffset: offset,
                date: date,
                weekdayText: weekdayFormatter.string(from: date),
                dayText: dayFormatter.string(from: date),
                isToday: calendar.isDate(date, inSameDayAs: currentDate),
                workouts: workouts
            )
        }
    }
}
