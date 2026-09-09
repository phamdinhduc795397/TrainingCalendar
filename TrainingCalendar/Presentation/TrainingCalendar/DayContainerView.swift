import SwiftUI

struct DayContainerView: View {
    let day: DayPresentation
    let isLoading: Bool
    let onWorkoutTap: (String) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: CalendarDesignTokens.dayHeaderSpacing) {
                Text(day.weekdayText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(day.isToday ? CalendarDesignTokens.brandPurple : CalendarDesignTokens.secondaryText)
                    .textCase(.uppercase)
                Text(day.dayText)
                    .foregroundStyle(day.isToday ? CalendarDesignTokens.brandPurple : CalendarDesignTokens.primaryText)
                    .font(.system(size: 22, weight: day.isToday ? .medium : .regular))
                    .fontWeight(day.isToday ? .bold : .regular)
                    .accessibilityIdentifier("day-date-\(day.weekdayOffset)")
            }
            .frame(width: CalendarDesignTokens.dayRailWidth, height: CalendarDesignTokens.minimumTapTargetHeight, alignment: .leading)

            VStack(alignment: .leading, spacing: CalendarDesignTokens.workoutSpacing) {
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, CalendarDesignTokens.dayVerticalPadding)
        .frame(minHeight: CalendarDesignTokens.dayMinimumHeight, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CalendarDesignTokens.separator)
                .frame(height: 1)
        }
        .accessibilityIdentifier("day-\(day.weekdayOffset)")
        .accessibilityElement(children: .contain)
    }
}
