import Foundation
import Testing
@testable import TrainingCalendar

struct WorkoutStatusResolverTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    @Test(arguments: [
        (-1, false, WorkoutDisplayStatus.missed),
        (0, false, WorkoutDisplayStatus.assigned),
        (1, false, WorkoutDisplayStatus.future),
        (-1, true, WorkoutDisplayStatus.completed),
        (0, true, WorkoutDisplayStatus.completed),
        (1, true, WorkoutDisplayStatus.completed)
    ])
    func resolvesStatus(dayOffset: Int, isCompleted: Bool, expected: WorkoutDisplayStatus) throws {
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 12)))
        let scheduled = try #require(calendar.date(byAdding: .day, value: dayOffset, to: today))

        let result = WorkoutStatusResolver.resolve(
            scheduledDate: scheduled,
            today: today,
            isCompleted: isCompleted,
            calendar: calendar
        )

        #expect(result == expected)
    }
}
