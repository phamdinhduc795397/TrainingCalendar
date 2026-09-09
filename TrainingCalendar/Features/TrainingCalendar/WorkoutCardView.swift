import SwiftUI

struct WorkoutCardView: View {
    let workout: WorkoutPresentation
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: CalendarDesignTokens.workoutContentSpacing) {
                VStack(alignment: .leading, spacing: CalendarDesignTokens.workoutTextSpacing) {
                    Text(workout.name)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(workout.exerciseCountText)
                        .font(.subheadline)
                        .foregroundStyle(CalendarDesignTokens.secondaryText)
                    if let statusText = workout.statusText {
                        Text(statusText)
                            .font(.caption.weight(.semibold))
                    }
                }
                Spacer(minLength: CalendarDesignTokens.workoutSpacing)
                if workout.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: CalendarDesignTokens.checkmarkSize))
                        .foregroundStyle(CalendarDesignTokens.brandPurple)
                        .accessibilityHidden(true)
                }
            }
            .frame(
                maxWidth: .infinity,
                minHeight: CalendarDesignTokens.minimumTapTargetHeight,
                alignment: .leading
            )
            .padding(CalendarDesignTokens.cardPadding)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: CalendarDesignTokens.cardCornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("workout-\(workout.id)")
        .accessibilityLabel(workout.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var backgroundColor: Color {
        switch workout.status {
        case .missed:
            CalendarDesignTokens.missedBackground
        case .assigned:
            CalendarDesignTokens.assignedBackground
        case .completed:
            CalendarDesignTokens.completedBackground
        case .future:
            CalendarDesignTokens.futureBackground
        }
    }
}
