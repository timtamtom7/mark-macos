import AppKit

// MARK: - Design System

enum Design {
    // MARK: - Colors - macOS 26 Liquid Glass

    enum Color {
        // Primary palette
        static let primary = NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        static let primaryDark = NSColor(red: 0.0, green: 0.35, blue: 0.8, alpha: 1.0)
        static let secondary = NSColor(red: 0.56, green: 0.27, blue: 1.0, alpha: 1.0)
        static let accent = NSColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0)

        // Semantic
        static let success = NSColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)
        static let warning = NSColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
        static let destructive = NSColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1.0)

        // Liquid Glass neutrals
        static let glassBackground = NSColor(white: 0.15, alpha: 0.72)
        static let glassBorder = NSColor(white: 1.0, alpha: 0.18)
        static let glassHighlight = NSColor(white: 1.0, alpha: 0.25)

        // Swatch colors (for color picker buttons)
        static let swatchBorder = NSColor(white: 1.0, alpha: 0.25)
        static let swatchBorderSelected = NSColor(white: 1.0, alpha: 0.4)

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

        static var titleScaled: NSFont {
            NSFont.preferredFont(forTextStyle: .headline).withWeight(.bold)
        }
        static var bodyScaled: NSFont {
            NSFont.preferredFont(forTextStyle: .body)
        }
        static var captionScaled: NSFont {
            NSFont.preferredFont(forTextStyle: .caption1)
        }
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

    // MARK: - Symbol Sizes

    enum SymbolSize {
        static let toolButton: CGFloat = 14
        static let actionButton: CGFloat = 12
        static let largeIcon: CGFloat = 64
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let toolbar: CGFloat = 16
        static let button: CGFloat = 6
    }

    // MARK: - Geometry (annotation renderer)

    enum Geometry {
        static let arrowLength: CGFloat = 20
        static let arrowAngle: CGFloat = .pi / 6
        static let blurRadius: CGFloat = 20
        static let pixelSize: CGFloat = 10
        static let swatchSmall: CGFloat = 18
        static let swatchMedium: CGFloat = 24
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
        view.layer?.backgroundColor = Color.glassBackground.cgColor
        view.layer?.cornerRadius = CornerRadius.toolbar
        view.layer?.borderWidth = 0.5
        view.layer?.borderColor = Color.glassBorder.cgColor
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

// MARK: - NSFont Weight Helper

extension NSFont {
    func withWeight(_ weight: NSFont.Weight) -> NSFont {
        let descriptor = fontDescriptor.addingAttributes([
            .traits: [NSFontDescriptor.TraitKey.weight: weight]
        ])
        return NSFont(descriptor: descriptor, size: pointSize) ?? self
    }
}
