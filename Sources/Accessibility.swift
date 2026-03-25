import AppKit

// MARK: - Accessibility Helpers

extension NSView {
    /// Set accessibility label, hint, and role in one call
    func setAccessibility(
        label: String,
        hint: String? = nil,
        role: NSAccessibility.Role? = nil,
        enabled: Bool = true
    ) {
        setAccessibilityLabel(label)
        if let hint = hint {
            setAccessibilityHelp(hint)
        }
        if let role = role {
            setAccessibilityRole(role)
        }
        setAccessibilityElement(true)
        setAccessibilityEnabled(enabled)
    }

    /// Configure as a button with standard accessibility
    func configureAsButton(label: String, hint: String? = nil) {
        setAccessibility(label: label, hint: hint, role: .button)
    }

    /// Configure as a static text label
    func configureAsLabel(label: String) {
        setAccessibility(label: label, role: .staticText)
    }

    /// Configure as a toolbar
    func configureAsToolbar(label: String) {
        setAccessibility(label: label, role: .toolbar)
    }

    /// Set accessibility role description
    func setAccessibilityRoleDescription(_ description: String) {
        setAccessibilityRoleDescription(description)
    }
}

// MARK: - Dynamic Type Support

extension NSFont {
    /// Get a scalable font for the given text style
    static func scaledFont(forTextStyle style: NSFont.TextStyle, weight: NSFont.Weight = .regular) -> NSFont {
        let font = NSFont.preferredFont(forTextStyle: style)
        return NSFont.systemFont(ofSize: font.pointSize, weight: weight)
    }
}

// MARK: - Reduce Motion

var isReduceMotionEnabled: Bool {
    return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
}

// MARK: - Accessibility Announcer

class AccessibilityAnnouncer {
    static let shared = AccessibilityAnnouncer()

    private init() {}

    func announce(_ message: String, delay: TimeInterval = 0.1) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // Post notification via accessibility API
            let announcement: [NSAccessibility.NotificationUserInfoKey: Any] = [
                .announcement: message
            ]
            if let window = NSApp.windows.first {
                NSAccessibility.post(element: window, notification: .announcementRequested, userInfo: announcement)
            }
        }
    }
}

// MARK: - Keyboard Navigation Helpers

extension NSView {
    /// Make view keyboard navigable
    func makeKeyboardNavigable() {
        // No-op for standard keyboard nav
    }
}
