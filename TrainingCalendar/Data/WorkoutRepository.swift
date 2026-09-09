import Foundation
import SwiftData

struct WorkoutSnapshot: Equatable {
    let definitions: [WorkoutDefinition]
    let completionOverrides: [String: Bool]

    static let empty = WorkoutSnapshot(definitions: [], completionOverrides: [:])

    func effectiveCompletion(for workoutID: String) -> Bool {
        guard let definition = definitions.first(where: { $0.id == workoutID }) else {
            return false
        }
        return completionOverrides[workoutID] ?? definition.initiallyCompleted
    }
}

enum WorkoutRepositoryError: Error, Equatable {
    case workoutNotFound(String)
}

@MainActor
protocol WorkoutRepositoryProtocol {
    func cachedSnapshot() async throws -> WorkoutSnapshot
    func refresh() async throws -> WorkoutSnapshot
    func toggleCompletion(workoutID: String) async throws -> WorkoutSnapshot
}

@MainActor
final class SwiftDataWorkoutRepository: WorkoutRepositoryProtocol {
    private let context: ModelContext
    private let source: any WorkoutFixtureSource
    private let now: () -> Date

    init(
        context: ModelContext,
        source: any WorkoutFixtureSource,
        now: @escaping () -> Date = Date.init
    ) {
        self.context = context
        self.source = source
        self.now = now
    }

    func cachedSnapshot() async throws -> WorkoutSnapshot {
        try snapshot()
    }

    func refresh() async throws -> WorkoutSnapshot {
        let definitions = try await source.load()
        let cached = try context.fetch(FetchDescriptor<CachedWorkout>())
        let overrides = try context.fetch(FetchDescriptor<WorkoutCompletionOverride>())
        let incomingIDs = Set(definitions.map(\.id))

        cached
            .filter { !incomingIDs.contains($0.id) }
            .forEach(context.delete)
        overrides
            .filter { !incomingIDs.contains($0.workoutID) }
            .forEach(context.delete)

        let cachedByID = Dictionary(uniqueKeysWithValues: cached.map { ($0.id, $0) })
        let refreshedAt = now()
        for definition in definitions {
            if let record = cachedByID[definition.id] {
                record.name = definition.name
                record.exerciseCount = definition.exerciseCount
                record.weekdayOffset = definition.weekdayOffset
                record.initiallyCompleted = definition.initiallyCompleted
                record.sortOrder = definition.sortOrder
                record.refreshedAt = refreshedAt
            } else {
                context.insert(CachedWorkout(definition: definition, refreshedAt: refreshedAt))
            }
        }

        try saveOrRollback()
        return try snapshot()
    }

    func toggleCompletion(workoutID: String) async throws -> WorkoutSnapshot {
        let current = try snapshot()
        guard current.definitions.contains(where: { $0.id == workoutID }) else {
            throw WorkoutRepositoryError.workoutNotFound(workoutID)
        }

        let descriptor = FetchDescriptor<WorkoutCompletionOverride>(
            predicate: #Predicate { $0.workoutID == workoutID }
        )
        let next = !current.effectiveCompletion(for: workoutID)
        if let value = try context.fetch(descriptor).first {
            value.isCompleted = next
            value.modifiedAt = now()
        } else {
            context.insert(
                WorkoutCompletionOverride(
                    workoutID: workoutID,
                    isCompleted: next,
                    modifiedAt: now()
                )
            )
        }

        try saveOrRollback()
        return try snapshot()
    }

    private func snapshot() throws -> WorkoutSnapshot {
        var descriptor = FetchDescriptor<CachedWorkout>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.id)]
        )
        descriptor.includePendingChanges = true
        let definitions = try context.fetch(descriptor).map(\.definition)
        let overrides = try context.fetch(FetchDescriptor<WorkoutCompletionOverride>())
        let completionOverrides = Dictionary(
            uniqueKeysWithValues: overrides.map { ($0.workoutID, $0.isCompleted) }
        )
        return WorkoutSnapshot(
            definitions: definitions,
            completionOverrides: completionOverrides
        )
    }

    private func saveOrRollback() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
