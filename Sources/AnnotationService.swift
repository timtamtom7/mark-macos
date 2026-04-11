import AppKit

// MARK: - Annotation Tool

enum AnnotationTool: Int, CaseIterable, Codable {
    case arrow = 0
    case rectangle = 1
    case ellipse = 2
    case line = 3
    case text = 4
    case freehand = 5
    case highlighter = 6
    case pixelate = 7
    case blur = 8

    var title: String {
        switch self {
        case .arrow: return "Arrow"
        case .rectangle: return "Rectangle"
        case .ellipse: return "Ellipse"
        case .line: return "Line"
        case .text: return "Text"
        case .freehand: return "Draw"
        case .highlighter: return "Highlight"
        case .pixelate: return "Pixelate"
        case .blur: return "Blur"
        }
    }

    var symbol: String {
        switch self {
        case .arrow: return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .ellipse: return "oval"
        case .line: return "line.diagonal"
        case .text: return "textformat"
        case .freehand: return "pencil.tip"
        case .highlighter: return "highlighter"
        case .pixelate: return "square.grid.3x3"
        case .blur: return "circle.lefthalf.filled"
        }
    }
}

// MARK: - Annotation Model

struct Annotation: Identifiable, Codable {
    let id: UUID
    let tool: AnnotationTool
    var startPoint: CGPoint
    var endPoint: CGPoint
    var colorData: Data?
    var strokeWidth: CGFloat
    var text: String?
    var points: [CGPoint]

    var color: NSColor {
        get {
            if let data = colorData,
               let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
                return color
            }
            return .red
        }
        set {
            colorData = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true)
        }
    }

    init(tool: AnnotationTool, startPoint: CGPoint, color: NSColor, strokeWidth: CGFloat) {
        self.id = UUID()
        self.tool = tool
        self.startPoint = startPoint
        self.endPoint = startPoint
        self.colorData = try? NSKeyedArchiver.archivedData(withRootObject: tool == .highlighter ? color.withAlphaComponent(0.3) : color, requiringSecureCoding: true)
        self.strokeWidth = strokeWidth
        self.text = nil
        self.points = [startPoint]
    }
}

extension CGPoint: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let x = try container.decode(CGFloat.self)
        let y = try container.decode(CGFloat.self)
        self.init(x: x, y: y)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(x)
        try container.encode(y)
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
    private let settingsStore: SettingsStore

    init(settings: SettingsStore) {
        self.settingsStore = settings
        self.strokeColor = settings.lastColor
        self.strokeWidth = settings.lastStrokeWidth
        self.currentTool = settings.lastTool
    }

    func beginAnnotation(at point: CGPoint) {
        if currentTool == .text {
            Task { @MainActor in
                let text = await requestTextInput(at: point)
                if let text = text, !text.isEmpty {
                    var annotation = Annotation(
                        tool: .text,
                        startPoint: point,
                        color: self.strokeColor,
                        strokeWidth: self.strokeWidth
                    )
                    annotation.text = text
                    self.addAnnotation(annotation)
                }
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
        undoManager.registerUndo(withTarget: self) { [weak self] target in
            guard let self = self else { return }
            self.removeAnnotation(id: annotation.id)
        }

        annotations.append(annotation)
        settingsStore.lastColor = annotation.color
        settingsStore.lastStrokeWidth = annotation.strokeWidth
        settingsStore.lastTool = annotation.tool
    }

    func removeAnnotation(id: UUID) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        let annotation = annotations[index]

        undoManager.registerUndo(withTarget: self) { [weak self] target in
            guard let self = self else { return }
            self.annotations.insert(annotation, at: index)
        }

        annotations.remove(at: index)
    }

    func clearAll() {
        let allAnnotations = annotations
        undoManager.registerUndo(withTarget: self) { [weak self] target in
            guard let self = self else { return }
            self.annotations.append(contentsOf: allAnnotations)
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

    func saveAnnotations(name: String) throws {
        try AnnotationStorage.shared.save(annotations, name: name)
    }

    func loadAnnotations(name: String) throws {
        let loaded = try AnnotationStorage.shared.load(name: name)
        annotations = loaded
    }

    var savedSessionNames: [String] {
        AnnotationStorage.shared.listSavedAnnotations()
    }

    private func requestTextInput(at point: CGPoint) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Add Text Annotation"
                alert.informativeText = "Enter the text to annotate:"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Add")
                alert.addButton(withTitle: "Cancel")

                let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
                textField.placeholderString = "Annotation text..."
                alert.accessoryView = textField

                if let window = NSApp.keyWindow {
                    alert.beginSheetModal(for: window) { response in
                        if response == .alertFirstButtonReturn {
                            continuation.resume(returning: textField.stringValue)
                        } else {
                            continuation.resume(returning: nil)
                        }
                    }
                } else {
                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        continuation.resume(returning: textField.stringValue)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
}
