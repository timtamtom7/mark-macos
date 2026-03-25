import AppKit

// MARK: - Annotation Tool

enum AnnotationTool: Int {
    case arrow = 0
    case rectangle = 1
    case text = 2
}

// MARK: - Annotation Model

struct Annotation: Identifiable {
    let id: UUID
    let tool: AnnotationTool
    var startPoint: CGPoint
    var endPoint: CGPoint
    var color: NSColor
    var strokeWidth: CGFloat
    var text: String?

    init(tool: AnnotationTool, startPoint: CGPoint, color: NSColor, strokeWidth: CGFloat) {
        self.id = UUID()
        self.tool = tool
        self.startPoint = startPoint
        self.endPoint = startPoint
        self.color = color
        self.strokeWidth = strokeWidth
        self.text = nil
    }
}

// MARK: - Annotation Service

class AnnotationService: ObservableObject {
    @Published var annotations: [Annotation] = []
    @Published var currentTool: AnnotationTool = .arrow
    @Published var strokeColor: NSColor = Theme.Color.red
    @Published var strokeWidth: CGFloat = 3.0

    private(set) var currentAnnotation: Annotation?

    init(settings: SettingsStore) {
        self.strokeColor = settings.lastColor
        self.strokeWidth = settings.lastStrokeWidth
        self.currentTool = settings.lastTool
    }

    func beginAnnotation(at point: CGPoint) {
        if currentTool == .text {
            let text = requestTextInput(at: point)
            if let text = text, !text.isEmpty {
                var annotation = Annotation(
                    tool: .text,
                    startPoint: point,
                    color: strokeColor,
                    strokeWidth: strokeWidth
                )
                annotation.text = text
                annotations.append(annotation)
            }
        } else {
            currentAnnotation = Annotation(
                tool: currentTool,
                startPoint: point,
                color: strokeColor,
                strokeWidth: strokeWidth
            )
        }
    }

    func updateAnnotation(to point: CGPoint) {
        guard var annotation = currentAnnotation else { return }
        annotation.endPoint = point
        currentAnnotation = annotation
    }

    func endAnnotation(at point: CGPoint) {
        guard var annotation = currentAnnotation else { return }
        annotation.endPoint = point

        // Only add if it has meaningful size
        let distance = hypot(annotation.endPoint.x - annotation.startPoint.x,
                            annotation.endPoint.y - annotation.startPoint.y)
        if distance > 5 {
            annotations.append(annotation)
        }

        currentAnnotation = nil
    }

    func clearAll() {
        annotations.removeAll()
        currentAnnotation = nil
    }

    private func requestTextInput(at point: CGPoint) -> String? {
        let alert = NSAlert()
        alert.messageText = "Add Text Annotation"
        alert.informativeText = "Enter the text to annotate:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        textField.placeholderString = "Annotation text..."
        alert.accessoryView = textField

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            return textField.stringValue
        }
        return nil
    }
}
