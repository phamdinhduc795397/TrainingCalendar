import SwiftUI
import UIKit

enum CalendarDesignTokens {
    static let screenHorizontalPadding: CGFloat = 0
    static let daySpacing: CGFloat = 0
    static let dayRailWidth: CGFloat = 116
    static let dayRailLeadingInset: CGFloat = 28
    static let dayHeaderSpacing: CGFloat = 4
    static let dayVerticalPadding: CGFloat = 20
    static let dayMinimumHeight: CGFloat = 124
    static let workoutSpacing: CGFloat = 10
    static let workoutContentSpacing: CGFloat = 12
    static let workoutTextSpacing: CGFloat = 5
    static let cardPadding: CGFloat = 18
    static let cardVerticalPadding: CGFloat = 16
    static let cardCornerRadius: CGFloat = 16
    static let minimumTapTargetHeight: CGFloat = 80
    static let errorSpacing: CGFloat = 8
    static let brandPurple = adaptiveColor(
        light: UIColor(red: 0.45, green: 0.42, blue: 0.93, alpha: 1),
        dark: UIColor(red: 0.63, green: 0.57, blue: 1.00, alpha: 1)
    )
    static let cardBackground = adaptiveColor(
        light: UIColor(red: 0.97, green: 0.97, blue: 0.99, alpha: 1),
        dark: UIColor(red: 0.13, green: 0.12, blue: 0.20, alpha: 1)
    )
    static let assignedBackground = cardBackground
    static let missedBackground = cardBackground
    static let futureBackground = cardBackground
    static let completedBackground = brandPurple
    static let primaryText = adaptiveColor(
        light: UIColor(red: 0.12, green: 0.05, blue: 0.27, alpha: 1),
        dark: UIColor(red: 0.95, green: 0.93, blue: 1.00, alpha: 1)
    )
    static let secondaryText = adaptiveColor(
        light: UIColor(red: 0.49, green: 0.50, blue: 0.60, alpha: 1),
        dark: UIColor(red: 0.71, green: 0.70, blue: 0.79, alpha: 1)
    )
    static let missedText = adaptiveColor(
        light: UIColor(red: 1.00, green: 0.34, blue: 0.38, alpha: 1),
        dark: UIColor(red: 1.00, green: 0.49, blue: 0.50, alpha: 1)
    )
    static let separator = adaptiveColor(
        light: UIColor(red: 0.93, green: 0.93, blue: 0.95, alpha: 1),
        dark: UIColor(red: 0.24, green: 0.23, blue: 0.29, alpha: 1)
    )
    static let completedText = Color.white
    static let checkmarkSize: CGFloat = 28

    private static func adaptiveColor(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}
