import Foundation

struct WorkoutDefinition: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let exerciseCount: Int
    let weekdayOffset: Int
    let initiallyCompleted: Bool
    let sortOrder: Int
}
