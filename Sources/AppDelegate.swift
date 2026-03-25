import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayWindow: OverlayWindow!
    private var annotationService: AnnotationService!
    private var settingsStore: SettingsStore!

    func applicationDidFinishLaunching(_ notification: Notification) {
        settingsStore = SettingsStore()
        annotationService = AnnotationService(settings: settingsStore)

        overlayWindow = OverlayWindow(
            annotationService: annotationService,
            settings: settingsStore
        )
        overlayWindow.makeKeyAndOrderFront(nil)

        setupMenu()
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    private func setupMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        appMenu.addItem(withTitle: "About Mark", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Mark", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // View menu
        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu

        viewMenu.addItem(withTitle: "Clear All Annotations", action: #selector(clearAnnotations), keyEquivalent: "k")
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(withTitle: "Toggle Overlay", action: #selector(toggleOverlay), keyEquivalent: "o")

        // Tools menu
        let toolsMenuItem = NSMenuItem()
        mainMenu.addItem(toolsMenuItem)
        let toolsMenu = NSMenu(title: "Tools")
        toolsMenuItem.submenu = toolsMenu

        toolsMenu.addItem(withTitle: "Arrow", action: #selector(selectArrowTool), keyEquivalent: "1")
        toolsMenu.addItem(withTitle: "Rectangle", action: #selector(selectRectangleTool), keyEquivalent: "2")
        toolsMenu.addItem(withTitle: "Text", action: #selector(selectTextTool), keyEquivalent: "3")

        // Settings menu
        let settingsMenuItem = NSMenuItem()
        mainMenu.addItem(settingsMenuItem)
        let settingsMenu = NSMenu(title: "Settings")
        settingsMenuItem.submenu = settingsMenu

        settingsMenu.addItem(withTitle: "Red", action: #selector(setColorRed), keyEquivalent: "r")
        settingsMenu.addItem(withTitle: "Blue", action: #selector(setColorBlue), keyEquivalent: "b")
        settingsMenu.addItem(withTitle: "Green", action: #selector(setColorGreen), keyEquivalent: "g")
        settingsMenu.addItem(withTitle: "Yellow", action: #selector(setColorYellow), keyEquivalent: "y")
        settingsMenu.addItem(withTitle: "White", action: #selector(setColorWhite), keyEquivalent: "w")

        NSApp.mainMenu = mainMenu
    }

    @objc private func clearAnnotations() {
        annotationService.clearAll()
        overlayWindow.refreshAnnotationView()
    }

    @objc private func toggleOverlay() {
        if overlayWindow.isVisible {
            overlayWindow.orderOut(nil)
        } else {
            overlayWindow.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func selectArrowTool() {
        annotationService.currentTool = .arrow
        overlayWindow.updateToolbar()
    }

    @objc private func selectRectangleTool() {
        annotationService.currentTool = .rectangle
        overlayWindow.updateToolbar()
    }

    @objc private func selectTextTool() {
        annotationService.currentTool = .text
        overlayWindow.updateToolbar()
    }

    @objc private func setColorRed() { annotationService.strokeColor = Theme.Color.red }
    @objc private func setColorBlue() { annotationService.strokeColor = Theme.Color.blue }
    @objc private func setColorGreen() { annotationService.strokeColor = Theme.Color.green }
    @objc private func setColorYellow() { annotationService.strokeColor = Theme.Color.yellow }
    @objc private func setColorWhite() { annotationService.strokeColor = Theme.Color.white }
}

// MARK: - Overlay Window

class OverlayWindow: NSPanel {
    private let annotationService: AnnotationService
    private let settings: SettingsStore
    private var annotationView: AnnotationView!
    private var toolbarView: ToolbarView!

    init(annotationService: AnnotationService, settings: SettingsStore) {
        self.annotationService = annotationService
        self.settings = settings

        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

        super.init(
            contentRect: screenFrame,
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

        annotationView = AnnotationView(frame: screenFrame, annotationService: annotationService)
        toolbarView = ToolbarView(annotationService: annotationService, settings: settings, overlayWindow: self)

        let containerView = NSView(frame: screenFrame)
        containerView.addSubview(annotationView)
        containerView.addSubview(toolbarView)

        self.contentView = containerView
    }

    func refreshAnnotationView() {
        annotationView.needsDisplay = true
    }

    func updateToolbar() {
        toolbarView.refresh()
    }
}

// MARK: - Annotation View

class AnnotationView: NSView {
    private let annotationService: AnnotationService
    private var trackingArea: NSTrackingArea?

    init(frame: NSRect, annotationService: AnnotationService) {
        self.annotationService = annotationService
        super.init(frame: frame)
        self.wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea {
            removeTrackingArea(ta)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)

        for annotation in annotationService.annotations {
            drawAnnotation(annotation, in: context)
        }

        if let current = annotationService.currentAnnotation {
            drawAnnotation(current, in: context)
        }
    }

    private func drawAnnotation(_ annotation: Annotation, in context: CGContext) {
        context.saveGState()
        context.setStrokeColor(annotation.color.cgColor)
        context.setFillColor(annotation.color.withAlphaComponent(0.1).cgColor)
        context.setLineWidth(annotation.strokeWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch annotation.tool {
        case .arrow:
            drawArrow(annotation, in: context)
        case .rectangle:
            drawRectangle(annotation, in: context)
        case .text:
            drawText(annotation, in: context)
        }

        context.restoreGState()
    }

    private func drawArrow(_ annotation: Annotation, in context: CGContext) {
        let start = annotation.startPoint
        let end = annotation.endPoint

        // Draw main line
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()

        // Draw arrowhead
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 20
        let arrowAngle: CGFloat = .pi / 6

        let point1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let point2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )

        context.move(to: end)
        context.addLine(to: point1)
        context.move(to: end)
        context.addLine(to: point2)
        context.strokePath()
    }

    private func drawRectangle(_ annotation: Annotation, in context: CGContext) {
        let rect = NSRect(
            x: min(annotation.startPoint.x, annotation.endPoint.x),
            y: min(annotation.startPoint.y, annotation.endPoint.y),
            width: abs(annotation.endPoint.x - annotation.startPoint.x),
            height: abs(annotation.endPoint.y - annotation.startPoint.y)
        )
        context.stroke(rect)
    }

    private func drawText(_ annotation: Annotation, in context: CGContext) {
        let text = annotation.text ?? ""
        guard !text.isEmpty else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: annotation.strokeWidth * 8, weight: .semibold),
            .foregroundColor: annotation.color
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()

        let point = annotation.startPoint

        // Draw background
        let bgRect = NSRect(x: point.x - 4, y: point.y - 2, width: textSize.width + 8, height: textSize.height + 4)
        context.setFillColor(annotation.color.withAlphaComponent(0.15).cgColor)
        context.fill(bgRect)

        // Draw text
        attributedString.draw(at: point)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        annotationService.beginAnnotation(at: point)
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        annotationService.updateAnnotation(to: point)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        annotationService.endAnnotation(at: point)
        needsDisplay = true
    }
}

// MARK: - Toolbar View

class ToolbarView: NSView {
    private let annotationService: AnnotationService
    private let settings: SettingsStore
    private weak var overlayWindow: OverlayWindow?
    private var toolButtons: [AnnotationTool: NSButton] = [:]
    private var strokeSlider: NSSlider!

    private let toolColors: [(tool: AnnotationTool, color: NSColor)] = [
        (.arrow, Theme.Color.red),
        (.rectangle, Theme.Color.yellow),
        (.text, Theme.Color.green)
    ]

    private let annotationColors: [NSColor] = [
        Theme.Color.red,
        Theme.Color.yellow,
        Theme.Color.green,
        Theme.Color.blue,
        Theme.Color.white
    ]

    init(annotationService: AnnotationService, settings: SettingsStore, overlayWindow: OverlayWindow) {
        self.annotationService = annotationService
        self.settings = settings
        self.overlayWindow = overlayWindow
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.1, alpha: 0.85).cgColor
        layer?.cornerRadius = 12
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(white: 0.3, alpha: 1).cgColor

        let stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.spacing = 8
        stackView.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -300)
        ])

        // Tool buttons
        let toolTitles: [AnnotationTool: String] = [
            .arrow: "➤",
            .rectangle: "□",
            .text: "T"
        ]
        for tool in [AnnotationTool.arrow, .rectangle, .text] {
            let button = NSButton(title: toolTitles[tool] ?? "", target: self, action: #selector(toolSelected(_:)))
            button.bezelStyle = .rounded
            button.tag = tool.rawValue
            button.widthAnchor.constraint(equalToConstant: 36).isActive = true
            button.heightAnchor.constraint(equalToConstant: 28).isActive = true
            toolButtons[tool] = button
            stackView.addArrangedSubview(button)
        }

        // Separator
        stackView.addArrangedSubview(createSeparator())

        // Color buttons
        for color in annotationColors {
            let button = NSButton()
            button.bezelStyle = .rounded
            button.isBordered = false
            button.wantsLayer = true
            button.layer?.backgroundColor = color.cgColor
            button.layer?.cornerRadius = 8
            button.layer?.borderWidth = 1
            button.layer?.borderColor = NSColor.white.withAlphaComponent(0.3).cgColor
            button.widthAnchor.constraint(equalToConstant: 20).isActive = true
            button.heightAnchor.constraint(equalToConstant: 20).isActive = true
            button.target = self
            button.action = #selector(colorSelected(_:))
            stackView.addArrangedSubview(button)
        }

        // Separator
        stackView.addArrangedSubview(createSeparator())

        // Stroke width label
        let strokeLabel = NSTextField(labelWithString: "Stroke:")
        strokeLabel.textColor = .white
        strokeLabel.font = NSFont.systemFont(ofSize: 11)
        stackView.addArrangedSubview(strokeLabel)

        // Stroke width slider
        strokeSlider = NSSlider(value: 3, minValue: 1, maxValue: 10, target: self, action: #selector(strokeChanged))
        strokeSlider.widthAnchor.constraint(equalToConstant: 80).isActive = true
        stackView.addArrangedSubview(strokeSlider)

        // Separator
        stackView.addArrangedSubview(createSeparator())

        // Clear button
        let clearButton = NSButton(title: "Clear", target: self, action: #selector(clearTapped))
        clearButton.bezelStyle = .rounded
        clearButton.setButtonType(.momentaryPushIn)
        stackView.addArrangedSubview(clearButton)

        refresh()
    }

    private func createSeparator() -> NSView {
        let sep = NSView()
        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor(white: 0.4, alpha: 1).cgColor
        sep.widthAnchor.constraint(equalToConstant: 1).isActive = true
        sep.heightAnchor.constraint(equalToConstant: 20).isActive = true
        return sep
    }

    @objc private func toolSelected(_ sender: NSButton) {
        guard let tool = AnnotationTool(rawValue: sender.tag) else { return }
        annotationService.currentTool = tool
        refresh()
    }

    @objc private func colorSelected(_ sender: NSButton) {
        guard let color = sender.layer?.backgroundColor.flatMap({ NSColor(cgColor: $0) }) else { return }
        annotationService.strokeColor = color
        refresh()
    }

    @objc private func strokeChanged(_ sender: NSSlider) {
        annotationService.strokeWidth = CGFloat(sender.doubleValue)
    }

    @objc private func clearTapped() {
        annotationService.clearAll()
        overlayWindow?.refreshAnnotationView()
    }

    func refresh() {
        for (tool, button) in toolButtons {
            let isSelected = annotationService.currentTool == tool
            button.layer?.backgroundColor = isSelected
                ? NSColor.selectedContentBackgroundColor.cgColor
                : NSColor.clear.cgColor
            button.layer?.cornerRadius = 4
        }
    }
}
