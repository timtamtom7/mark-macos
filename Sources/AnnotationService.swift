import AppKit

// MARK: - Annotation Tool

enum AnnotationTool: Int, CaseIterable, Codable {
    case arrow = 0
    case rectangle = 1
    case text = 2
    case freehand = 3
    case highlighter = 4

    var title: String {
        switch self {
        case .arrow: return "Arrow"
        case .rectangle: return "Rectangle"
        case .text: return "Text"
        case .freehand: return "Draw"
        case .highlighter: return "Highlight"
        }
    }

    var symbol: String {
        switch self {
        case .arrow: return "➤"
        case .rectangle: return "□"
        case .text: return "T"
        case .freehand: return "✎"
        case .highlighter: return "▬"
        }
    }
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
    var points: [CGPoint]  // for freehand/highlighter

    init(tool: AnnotationTool, startPoint: CGPoint, color: NSColor, strokeWidth: CGFloat) {
        self.id = UUID()
        self.tool = tool
        self.startPoint = startPoint
        self.endPoint = startPoint
        self.color = tool == .highlighter ? color.withAlphaComponent(0.3) : color
        self.strokeWidth = strokeWidth
        self.text = nil
        self.points = [startPoint]
    }
}

// MARK: - Annotation Service

class AnnotationService: ObservableObject {
    @Published var annotations: [Annotation] = []
    @Published var currentTool: AnnotationTool = .arrow
    @Published var strokeColor: NSColor = Theme.Color.red
    @Published var strokeWidth: CGFloat = 3.0

    private(set) var currentAnnotation: Annotation?

    let undoManager = UndoManager()

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
                addAnnotation(annotation)
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

        switch annotation.tool {
        case .freehand, .highlighter:
            annotation.points.append(point)
            annotation.endPoint = point
        default:
            annotation.endPoint = point
        }
        currentAnnotation = annotation
    }

    func endAnnotation(at point: CGPoint) {
        guard var annotation = currentAnnotation else { return }
        annotation.endPoint = point

        if annotation.tool == .freehand || annotation.tool == .highlighter {
            annotation.points.append(point)
        }

        // Only add if it has meaningful size
        let distance = hypot(annotation.endPoint.x - annotation.startPoint.x,
                            annotation.endPoint.y - annotation.startPoint.y)
        if distance > 5 || annotation.tool == .text {
            addAnnotation(annotation)
        }

        currentAnnotation = nil
    }

    private func addAnnotation(_ annotation: Annotation) {
        // Register undo
        undoManager.registerUndo(withTarget: self) { target in
            target.removeAnnotation(id: annotation.id)
        }

        annotations.append(annotation)
        settingsStore_?.lastColor = annotation.color
        settingsStore_?.lastStrokeWidth = annotation.strokeWidth
        settingsStore_?.lastTool = annotation.tool
    }

    private var settingsStore_: SettingsStore?

    func setSettingsStore(_ store: SettingsStore) {
        self.settingsStore_ = store
    }

    func removeAnnotation(id: UUID) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        let annotation = annotations[index]

        undoManager.registerUndo(withTarget: self) { target in
            target.annotations.insert(annotation, at: index)
        }

        annotations.remove(at: index)
    }

    func clearAll() {
        let allAnnotations = annotations
        undoManager.registerUndo(withTarget: self) { target in
            target.annotations.append(contentsOf: allAnnotations)
        }
        annotations.removeAll()
        currentAnnotation = nil
    }

    func undo() {
        undoManager.undo()
    }

    func redo() {
        undoManager.redo()
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
