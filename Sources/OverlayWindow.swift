import AppKit

class OverlayWindow: NSPanel {
    private let annotationService: AnnotationService
    private let settings: SettingsStore
    private var annotationView: AnnotationView!
    private var toolbarView: ToolbarView!

    init(annotationService: AnnotationService, settings: SettingsStore) {
        self.annotationService = annotationService
        self.settings = settings

        let fullFrame = OverlayWindow.calculateFullScreenFrame()

        super.init(
            contentRect: fullFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.isMovableByWindowBackground = false

        annotationView = AnnotationView(frame: fullFrame, annotationService: annotationService)
        toolbarView = ToolbarView(annotationService: annotationService, settings: settings, overlayWindow: self)

        let containerView = NSView(frame: fullFrame)
        containerView.addSubview(annotationView)
        containerView.addSubview(toolbarView)

        self.contentView = containerView
    }

    private static func calculateFullScreenFrame() -> NSRect {
        guard let mainScreen = NSScreen.main else {
            return NSRect(x: 0, y: 0, width: 1920, height: 1080)
        }

        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for screen in NSScreen.screens {
            minX = min(minX, screen.frame.minX)
            minY = min(minY, screen.frame.minY)
            maxX = max(maxX, screen.frame.maxX)
            maxY = max(maxY, screen.frame.maxY)
        }

        return NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    func refreshAnnotationView() {
        annotationView.needsDisplay = true
    }

    func updateToolbar() {
        toolbarView.refresh()
    }
}
