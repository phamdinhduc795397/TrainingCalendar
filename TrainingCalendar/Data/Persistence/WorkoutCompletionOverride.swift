import Foundation
import SwiftData

@Model
final class WorkoutCompletionOverride {
    @Attribute(.unique) var workoutID: String
    var isCompleted: Bool
    var modifiedAt: Date

    init(workoutID: String, isCompleted: Bool, modifiedAt: Date) {
        self.workoutID = workoutID
        self.isCompleted = isCompleted
        self.modifiedAt = modifiedAt
    }
}
