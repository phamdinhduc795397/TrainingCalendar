import Foundation

enum WorkoutDisplayStatus: Equatable, Sendable {
    case missed
    case assigned
    case future
    case completed

    var label: String? {
        switch self {
        case .missed: "Missed"
        case .assigned: "Assigned"
        case .completed: "Completed"
        case .future: nil
        }
    }
}

enum WorkoutStatusResolver {
    static func resolve(
        scheduledDate: Date,
        today: Date,
        isCompleted: Bool,
        calendar: Calendar
    ) -> WorkoutDisplayStatus {
        let scheduledDay = calendar.startOfDay(for: scheduledDate)
        let currentDay = calendar.startOfDay(for: today)
        if scheduledDay > currentDay { return .future }
        if isCompleted { return .completed }
        if scheduledDay < currentDay { return .missed }
        return .assigned
    }
}
