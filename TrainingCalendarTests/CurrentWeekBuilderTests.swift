import Foundation
import Testing
@testable import TrainingCalendar

struct CurrentWeekBuilderTests {
    @Test func buildsMondayThroughSundayAcrossYearBoundary() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US")
        let now = try #require(calendar.date(from: DateComponents(year: 2027, month: 1, day: 1, hour: 12)))

        let days = try CurrentWeekBuilder.days(containing: now, calendar: calendar)

        #expect(days.count == 7)
        let monday = calendar.dateComponents([.year, .month, .day], from: days[0])
        let sunday = calendar.dateComponents([.year, .month, .day], from: days[6])
        #expect(monday.year == 2026 && monday.month == 12 && monday.day == 28)
        #expect(sunday.year == 2027 && sunday.month == 1 && sunday.day == 3)
    }

    @Test func remainsMondayFirstForSundayFirstLocale() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US")
        calendar.firstWeekday = 1
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 9)))

        let days = try CurrentWeekBuilder.days(containing: now, calendar: calendar)

        #expect(calendar.component(.weekday, from: days[0]) == 2)
        #expect(calendar.component(.weekday, from: days[6]) == 1)
    }
}
