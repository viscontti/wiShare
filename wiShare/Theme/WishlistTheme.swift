import UIKit

/// Palette and metrics for the app.
///
/// The design leans on system semantic colors for surfaces (so light/dark and
/// contrast settings come for free) and uses turquoise strictly as the accent:
/// tint, selected states, icon tiles and prominent buttons.
enum WishlistTheme {
    /// Primary accent. Controls, tints, prominent buttons.
    static let accent = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.29, green: 0.82, blue: 0.80, alpha: 1.00)
            : UIColor(red: 0.00, green: 0.62, blue: 0.62, alpha: 1.00)
    }

    /// Deeper shade for text on tinted surfaces and for badges.
    static let accentDeep = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.52, green: 0.90, blue: 0.88, alpha: 1.00)
            : UIColor(red: 0.00, green: 0.44, blue: 0.46, alpha: 1.00)
    }

    /// Tinted fill for icon tiles, chips and image placeholders.
    static let accentSoft = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.25, blue: 0.26, alpha: 1.00)
            : UIColor(red: 0.89, green: 0.97, blue: 0.97, alpha: 1.00)
    }

    /// Screen background behind grouped content.
    static let background = UIColor.systemGroupedBackground

    /// Card / row surface inside grouped content.
    static let surface = UIColor.secondarySystemGroupedBackground

    enum Metrics {
        static let corner: CGFloat = 12
        static let tileCorner: CGFloat = 11
        static let tile: CGFloat = 44
        static let thumbnail: CGFloat = 56
        static let margin: CGFloat = 16
        static let rowHeight: CGFloat = 44
        static let buttonHeight: CGFloat = 50
    }

    /// SF Symbols offered when picking an icon for a wishlist.
    static let symbolCatalog = [
        "gift", "heart.fill", "star.fill", "sparkles", "house.fill",
        "airplane", "gamecontroller.fill", "book.fill", "headphones",
        "tshirt.fill", "cup.and.saucer.fill", "laptopcomputer",
        "camera.fill", "bicycle", "pawprint.fill", "cart.fill"
    ]

    static let defaultSymbol = "gift"

    static func applyAppearance() {
        UINavigationBar.appearance().tintColor = accent
    }
}
