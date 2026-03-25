import AppKit

enum Theme {
    enum Color {
        static let red = NSColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1.0)
        static let blue = NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        static let green = NSColor(red: 0.18, green: 0.8, blue: 0.25, alpha: 1.0)
        static let yellow = NSColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
        static let white = NSColor.white
        static let orange = NSColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0)
        static let purple = NSColor(red: 0.69, green: 0.32, blue: 1.0, alpha: 1.0)
    }

    enum Font {
        static let toolbar = NSFont.systemFont(ofSize: 13, weight: .medium)
        static let annotation = NSFont.systemFont(ofSize: 24, weight: .bold)
    }

    enum Layout {
        static let toolbarHeight: CGFloat = 48
        static let toolbarCornerRadius: CGFloat = 12
        static let buttonSize: CGFloat = 28
    }
}
