import SwiftUI

struct DayContainerView: View {
    let day: DayPresentation
    let isLoading: Bool
    let onWorkoutTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CalendarDesignTokens.workoutSpacing) {
            VStack(alignment: .leading, spacing: CalendarDesignTokens.dayHeaderSpacing) {
                Text(day.weekdayText)
                Text(day.dayText)
                    .foregroundStyle(day.isToday ? CalendarDesignTokens.brandPurple : CalendarDesignTokens.primaryText)
                    .fontWeight(day.isToday ? .bold : .regular)
            }

            ForEach(day.workouts) { workout in
                WorkoutCardView(workout: workout) {
                    onWorkoutTap(workout.id)
                }
            }

            if isLoading && day.workouts.isEmpty {
                WorkoutCardView(workout: .placeholder, onTap: {})
                    .redacted(reason: .placeholder)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityIdentifier("day-\(day.weekdayOffset)")
        .accessibilityElement(children: .contain)
    }
}
