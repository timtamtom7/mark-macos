import AppKit

// MARK: - Design System

enum Design {
    // MARK: - Colors

    enum Color {
        // Primary palette
        static let primary = NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)        // Blue
        static let primaryDark = NSColor(red: 0.0, green: 0.35, blue: 0.8, alpha: 1.0)
        static let secondary = NSColor(red: 0.56, green: 0.27, blue: 1.0, alpha: 1.0)     // Purple
        static let accent = NSColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0)        // Orange

        // Semantic
        static let success = NSColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)
        static let warning = NSColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
        static let destructive = NSColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1.0)

        // Neutral
        static let background = NSColor(white: 0.1, alpha: 0.85)
        static let backgroundSecondary = NSColor(white: 0.15, alpha: 0.9)
        static let border = NSColor(white: 0.3, alpha: 1.0)
        static let textPrimary = NSColor.white
        static let textSecondary = NSColor(white: 0.7, alpha: 1.0)
        static let textTertiary = NSColor(white: 0.5, alpha: 1.0)
    }

    // MARK: - Typography

    enum Typography {
        static let title = NSFont.systemFont(ofSize: 20, weight: .bold)
        static let headline = NSFont.systemFont(ofSize: 16, weight: .semibold)
        static let body = NSFont.systemFont(ofSize: 13, weight: .regular)
        static let caption = NSFont.systemFont(ofSize: 11, weight: .regular)
        static let small = NSFont.systemFont(ofSize: 9, weight: .regular)

        // Dynamic Type variants
        static let titleScaled = NSFont.scaledFont(forTextStyle: .headline, weight: .bold)
        static let bodyScaled = NSFont.scaledFont(forTextStyle: .body, weight: .regular)
        static let captionScaled = NSFont.scaledFont(forTextStyle: .caption1, weight: .regular)
    }

    // MARK: - Spacing (8pt grid)

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48

        static let toolbarPadding: CGFloat = 12
        static let buttonSpacing: CGFloat = 8
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let toolbar: CGFloat = 12
        static let button: CGFloat = 6
    }

    // MARK: - Animation

    enum Animation {
        static let fast: TimeInterval = 0.15
        static let normal: TimeInterval = 0.25
        static let slow: TimeInterval = 0.35

        static var reduceMotionDuration: TimeInterval {
            return isReduceMotionEnabled ? 0.0 : normal
        }
    }

    // MARK: - Shadows

    enum Shadow {
        static func apply(to view: NSView, radius: CGFloat = 4, opacity: Float = 0.15, offset: CGSize = CGSize(width: 0, height: 2)) {
            view.wantsLayer = true
            view.layer?.shadowColor = NSColor.black.cgColor
            view.layer?.shadowOpacity = opacity
            view.layer?.shadowRadius = radius
            view.layer?.shadowOffset = offset
        }
    }

    // MARK: - Component Styles

    static func styleToolbar(_ view: NSView) {
        view.wantsLayer = true
        view.layer?.backgroundColor = Color.background.cgColor
        view.layer?.cornerRadius = CornerRadius.toolbar
        view.layer?.borderWidth = 1
        view.layer?.borderColor = Color.border.cgColor
    }

    static func styleButton(_ button: NSButton, isPrimary: Bool = false) {
        button.bezelStyle = .rounded
        if isPrimary {
            button.contentTintColor = .white
        }
    }
}

// MARK: - NSColor Semantic Helpers

extension NSColor {
    static var semanticPrimary: NSColor { Design.Color.primary }
    static var semanticSecondary: NSColor { Design.Color.secondary }
    static var semanticSuccess: NSColor { Design.Color.success }
    static var semanticWarning: NSColor { Design.Color.warning }
    static var semanticDestructive: NSColor { Design.Color.destructive }
}
