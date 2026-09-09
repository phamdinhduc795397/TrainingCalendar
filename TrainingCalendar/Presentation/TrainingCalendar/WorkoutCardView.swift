import SwiftUI

struct WorkoutCardView: View {
    let workout: WorkoutPresentation
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: CalendarDesignTokens.workoutContentSpacing) {
                VStack(alignment: .leading, spacing: CalendarDesignTokens.workoutTextSpacing) {
                    Text(workout.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(titleColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    metadata
                }
                Spacer(minLength: CalendarDesignTokens.workoutSpacing)
                if workout.status == .completed {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(CalendarDesignTokens.brandPurple)
                    }
                    .frame(width: CalendarDesignTokens.checkmarkSize, height: CalendarDesignTokens.checkmarkSize)
                        .accessibilityHidden(true)
                }
            }
            .frame(
                maxWidth: .infinity,
                minHeight: CalendarDesignTokens.minimumTapTargetHeight,
                alignment: .leading
            )
            .padding(.horizontal, CalendarDesignTokens.cardPadding)
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

    private var titleColor: Color {
        switch workout.status {
        case .completed:
            CalendarDesignTokens.completedText
        case .future:
            CalendarDesignTokens.secondaryText
        case .missed, .assigned:
            CalendarDesignTokens.primaryText
        }
    }

    @ViewBuilder
    private var metadata: some View {
        switch workout.status {
        case .missed:
            HStack(spacing: 6) {
                Text("Missed")
                    .foregroundStyle(CalendarDesignTokens.missedText)
                Text("•")
                    .foregroundStyle(CalendarDesignTokens.primaryText)
                Text(workout.exerciseCountText)
                    .foregroundStyle(CalendarDesignTokens.primaryText)
            }
            .font(.system(size: 14, weight: .regular))
        case .completed:
            Text("Completed")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(CalendarDesignTokens.completedText)
        case .assigned:
            HStack(spacing: 6) {
                Text("Assigned")
                    .foregroundStyle(CalendarDesignTokens.primaryText)
                Text("•")
                    .foregroundStyle(CalendarDesignTokens.primaryText)
                Text(workout.exerciseCountText)
                    .foregroundStyle(CalendarDesignTokens.primaryText)
            }
            .font(.system(size: 14, weight: .regular))
        case .future:
            Text(workout.exerciseCountText)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(CalendarDesignTokens.secondaryText)
        }
    }
}
