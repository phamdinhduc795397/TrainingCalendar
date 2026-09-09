import Foundation

enum CurrentWeekBuilderError: Error {
    case cannotDetermineMonday
    case cannotCreateDay(Int)
}

enum CurrentWeekBuilder {
    static func days(containing date: Date, calendar source: Calendar) throws -> [Date] {
        var calendar = source
        calendar.firstWeekday = 2
        let normalized = calendar.startOfDay(for: date)
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: normalized) else {
            throw CurrentWeekBuilderError.cannotDetermineMonday
        }
        return try (0..<7).map { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: interval.start) else {
                throw CurrentWeekBuilderError.cannotCreateDay(offset)
            }
            return calendar.startOfDay(for: day)
        }
    }
}
