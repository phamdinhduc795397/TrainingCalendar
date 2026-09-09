import Foundation
import SwiftData

@Model
final class CachedWorkout {
    @Attribute(.unique) var id: String
    var name: String
    var exerciseCount: Int
    var weekdayOffset: Int
    var initiallyCompleted: Bool
    var sortOrder: Int
    var refreshedAt: Date

    init(definition: WorkoutDefinition, refreshedAt: Date) {
        id = definition.id
        name = definition.name
        exerciseCount = definition.exerciseCount
        weekdayOffset = definition.weekdayOffset
        initiallyCompleted = definition.initiallyCompleted
        sortOrder = definition.sortOrder
        self.refreshedAt = refreshedAt
    }

    var definition: WorkoutDefinition {
        WorkoutDefinition(
            id: id,
            name: name,
            exerciseCount: exerciseCount,
            weekdayOffset: weekdayOffset,
            initiallyCompleted: initiallyCompleted,
            sortOrder: sortOrder
        )
    }
}
