import SwiftUI
import UIKit

enum CalendarDesignTokens {
    static let screenHorizontalPadding: CGFloat = 16
    static let daySpacing: CGFloat = 12
    static let dayHeaderSpacing: CGFloat = 2
    static let workoutSpacing: CGFloat = 8
    static let workoutContentSpacing: CGFloat = 12
    static let workoutTextSpacing: CGFloat = 4
    static let cardPadding: CGFloat = 12
    static let cardCornerRadius: CGFloat = 8
    static let minimumTapTargetHeight: CGFloat = 44
    static let errorSpacing: CGFloat = 8
    static let brandPurple = adaptiveColor(
        light: UIColor(red: 0.42, green: 0.25, blue: 0.88, alpha: 1),
        dark: UIColor(red: 0.70, green: 0.59, blue: 1.00, alpha: 1)
    )
    static let assignedBackground = Color(uiColor: .secondarySystemBackground)
    static let missedBackground = adaptiveColor(
        light: UIColor(red: 1.00, green: 0.94, blue: 0.94, alpha: 1),
        dark: UIColor(red: 0.32, green: 0.08, blue: 0.10, alpha: 1)
    )
    static let completedBackground = adaptiveColor(
        light: UIColor(red: 0.92, green: 0.97, blue: 0.94, alpha: 1),
        dark: UIColor(red: 0.06, green: 0.27, blue: 0.14, alpha: 1)
    )
    static let futureBackground = Color(uiColor: .systemGray6)
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let checkmarkSize: CGFloat = 20

    private static func adaptiveColor(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}
