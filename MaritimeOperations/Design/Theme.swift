import SwiftUI
import UIKit

/// Liquid Glass tokens (Pixel, 8 Oct 2026). One teal, one gold, one secondary, one primary text.
/// Increase Contrast swaps the pairs that define an IC hex. Glass is floating chrome only;
/// content cards use `card` + `cardBorder`.
enum AppTheme {
    static let background = color(0x0D161D)
    static let card = color(0x1B2327)
    static let textPrimary = color(0xEEF3F7)
    static let onTeal = color(0x0D2A26)

    static let teal = dynamic(0x76C8B8, contrast: 0x9ADFD1)
    static let gold = dynamic(0xD9AD52, contrast: 0xF0C66A)
    static let textSecondary = dynamic(0xB4BEC4, contrast: 0xD0D8DC)
    static let fieldBorder = dynamic(0x748389, contrast: 0x9AA8AE)
    static let toggleOff = dynamic(0x748389, contrast: 0x9AA8AE)
    static let cardBorder = dynamic(0x3A474D, contrast: 0x55656C)

    /// Decorative hairline (dividers). Control strokes use `fieldBorder`.
    static let border = cardBorder

    /// Interior shades. No contrast target; documented beside the token sheet.
    static let surface = color(0x141B1F)
    static let surfaceElevated = color(0x252D31)
    static let pickerFill = color(0x283034)
    static let badgeFill = color(0x0B141A)
    static let ready = color(0x3DDC6A)

    static let danger = color(0xF25959)

    private static func color(_ hex: UInt32) -> Color {
        Color(uiColor: uiColor(hex))
    }

    private static func dynamic(_ hex: UInt32, contrast: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            uiColor(traits.accessibilityContrast == .high ? contrast : hex)
        })
    }

    private static func uiColor(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
