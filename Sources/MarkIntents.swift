import AppIntents
import AppKit

// MARK: - Open Mark Intent

struct OpenMarkIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Mark"
    static var description = IntentDescription("Opens the Mark overlay for annotation")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return .result()
    }
}

// MARK: - Capture Screen Intent

struct CaptureScreenIntent: AppIntent {
    static var title: LocalizedStringResource = "Capture Screen"
    static var description = IntentDescription("Capture the screen with Mark")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            // Trigger screen capture via DistributedNotificationCenter or similar
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name("com.mark.captureScreen"),
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
        }
        return .result()
    }
}

// MARK: - Open File Intent

struct OpenFileIntent: AppIntent {
    static var title: LocalizedStringResource = "Open File in Mark"
    static var description = IntentDescription("Opens a file for annotation in Mark")

    @Parameter(title: "File Path")
    var filePath: String

    init() {
        self.filePath = ""
    }

    init(filePath: String) {
        self.filePath = filePath
    }

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        await MainActor.run {
            NSApp.activate(ignoringOtherApps: true)
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name("com.mark.openFile"),
                object: nil,
                userInfo: ["filePath": filePath],
                deliverImmediately: true
            )
        }
        return .result(value: "Opened \(filePath)")
    }
}

// MARK: - Clear Annotations Intent

struct ClearAnnotationsIntent: AppIntent {
    static var title: LocalizedStringResource = "Clear All Annotations"
    static var description = IntentDescription("Clears all current annotations in Mark")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name("com.mark.clearAnnotations"),
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
        }
        return .result()
    }
}

// MARK: - Set Tool Intent

struct SetToolIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Annotation Tool"
    static var description = IntentDescription("Sets the current annotation tool in Mark")

    @Parameter(title: "Tool", default: .arrow)
    var tool: ToolArgument

    enum ToolArgument: String, AppEnum {
        case arrow
        case rectangle
        case text
        case freehand
        case highlighter

        static var typeDisplayRepresentation: TypeDisplayRepresentation = "Annotation Tool"
        static var caseDisplayRepresentations: [ToolArgument: DisplayRepresentation] = [
            .arrow: "Arrow",
            .rectangle: "Rectangle",
            .text: "Text",
            .freehand: "Freehand",
            .highlighter: "Highlighter"
        ]
    }

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name("com.mark.setTool"),
                object: nil,
                userInfo: ["tool": tool.rawValue],
                deliverImmediately: true
            )
        }
        return .result()
    }
}

// MARK: - App Shortcuts Provider

// MARK: - App Shortcuts Provider
// Available in macOS 14+: MarkShortcutsProvider (use App Store Connect to add Siri phrases for macOS 13)
