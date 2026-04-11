import AppKit

class ToolbarView: NSView {
    private let annotationService: AnnotationService
    private let settings: SettingsStore
    private weak var overlayWindow: OverlayWindow?
    // NSButton is not Sendable; this dictionary is only accessed from main thread
    private var toolButtons: [AnnotationTool: NSButton] = [:]
    private var strokeSlider: NSSlider!
    private var undoButton: NSButton!
    private var redoButton: NSButton!
    private var colorWellButton: NSButton!

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
        layer?.cornerRadius = Design.CornerRadius.toolbar
        layer?.borderWidth = 0.5
        layer?.borderColor = Design.Color.glassBorder.cgColor
        
        let visualEffect = NSVisualEffectView(frame: bounds)
        visualEffect.material = .popover
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = Design.CornerRadius.toolbar
        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        addSubview(visualEffect, positioned: .below, relativeTo: nil)
        
        NSLayoutConstraint.activate([
            visualEffect.topAnchor.constraint(equalTo: topAnchor),
            visualEffect.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        setAccessibility(label: "Annotation Toolbar", role: .toolbar)

        let stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.spacing = Design.Spacing.buttonSpacing
        stackView.edgeInsets = NSEdgeInsets(top: Design.Spacing.sm, left: Design.Spacing.toolbarPadding, bottom: Design.Spacing.sm, right: Design.Spacing.toolbarPadding)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -300)
        ])

        let toolSymbols: [AnnotationTool: String] = [
            .arrow: "arrow.up.right",
            .rectangle: "rectangle",
            .ellipse: "circle",
            .line: "line.diagonal",
            .text: "textformat",
            .freehand: "pencil.tip",
            .highlighter: "highlighter",
            .pixelate: "square.grid.3x3",
            .blur: "drop.fill"
        ]
        for tool in AnnotationTool.allCases {
            let button = NSButton()
            button.bezelStyle = .texturedRounded
            button.isBordered = false
            button.tag = tool.rawValue
            button.widthAnchor.constraint(equalToConstant: 32).isActive = true
            button.heightAnchor.constraint(equalToConstant: 28).isActive = true
            
            if let symbolName = toolSymbols[tool],
               let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: tool.title) {
                let config = NSImage.SymbolConfiguration(pointSize: Design.SymbolSize.toolButton, weight: .medium)
                button.image = image.withSymbolConfiguration(config)
                button.contentTintColor = .white
            }
            
            button.target = self
            button.action = #selector(toolSelected(_:))
            button.configureAsButton(label: "\(tool.title) tool", hint: "Switch to \(tool.title.lowercased()) annotation")
            button.setAccessibilityRoleDescription(tool.title)
            toolButtons[tool] = button
            stackView.addArrangedSubview(button)
        }

        stackView.addArrangedSubview(createSeparator())

        colorWellButton = NSButton()
        colorWellButton.bezelStyle = .texturedRounded
        colorWellButton.isBordered = false
        colorWellButton.wantsLayer = true
        colorWellButton.layer?.backgroundColor = annotationService.strokeColor.cgColor
        colorWellButton.layer?.cornerRadius = Design.CornerRadius.medium
        colorWellButton.layer?.borderWidth = 1.5
        colorWellButton.layer?.borderColor = Design.Color.swatchBorderSelected.cgColor
        colorWellButton.widthAnchor.constraint(equalToConstant: Design.Geometry.swatchMedium).isActive = true
        colorWellButton.heightAnchor.constraint(equalToConstant: Design.Geometry.swatchMedium).isActive = true
        colorWellButton.target = self
        colorWellButton.action = #selector(openColorPanel)
        colorWellButton.toolTip = "Color Picker"
        colorWellButton.configureAsButton(label: "Color picker", hint: "Opens system color picker")
        colorWellButton.setAccessibilityRoleDescription("Color picker")
        stackView.addArrangedSubview(colorWellButton)

        let colorNames = ["Red", "Yellow", "Green", "Blue", "White"]
        for (index, color) in annotationColors.enumerated() {
            let button = NSButton()
            button.bezelStyle = .texturedRounded
            button.isBordered = false
            button.wantsLayer = true
            button.layer?.backgroundColor = color.cgColor
            button.layer?.cornerRadius = Design.CornerRadius.button
            button.layer?.borderWidth = 1
            button.layer?.borderColor = Design.Color.swatchBorder.cgColor
            button.widthAnchor.constraint(equalToConstant: Design.Geometry.swatchSmall).isActive = true
            button.heightAnchor.constraint(equalToConstant: Design.Geometry.swatchSmall).isActive = true
            button.target = self
            button.action = #selector(colorSelected(_:))
            button.tag = index
            button.configureAsButton(label: "\(colorNames[index]) color", hint: "Set annotation color to \(colorNames[index].lowercased())")
            stackView.addArrangedSubview(button)
        }

        stackView.addArrangedSubview(createSeparator())

        let strokeLabel = NSTextField(labelWithString: "Stroke:")
        strokeLabel.textColor = .white
        strokeLabel.font = Design.Typography.captionScaled
        strokeLabel.configureAsLabel(label: "Stroke width")
        strokeLabel.setAccessibilityRoleDescription("Stroke width label")
        stackView.addArrangedSubview(strokeLabel)

        strokeSlider = NSSlider(value: 3, minValue: 1, maxValue: 10, target: self, action: #selector(strokeChanged))
        strokeSlider.widthAnchor.constraint(equalToConstant: 80).isActive = true
        strokeSlider.setAccessibilityLabel("Stroke Width")
        strokeSlider.setAccessibilityHelp("Adjust annotation stroke width from thin to thick")
        stackView.addArrangedSubview(strokeSlider)

        stackView.addArrangedSubview(createSeparator())

        undoButton = NSButton()
        undoButton.bezelStyle = .texturedRounded
        undoButton.isBordered = false
        if let undoImage = NSImage(systemSymbolName: "arrow.uturn.backward", accessibilityDescription: "Undo") {
            undoButton.image = undoImage.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: Design.SymbolSize.actionButton, weight: .medium))
            undoButton.contentTintColor = .white
        }
        undoButton.widthAnchor.constraint(equalToConstant: 28).isActive = true
        undoButton.toolTip = "Undo (⌘Z)"
        undoButton.target = self
        undoButton.action = #selector(undoTapped)
        undoButton.configureAsButton(label: "Undo", hint: "Undo last annotation (⌘Z)")
        stackView.addArrangedSubview(undoButton)

        redoButton = NSButton()
        redoButton.bezelStyle = .texturedRounded
        redoButton.isBordered = false
        if let redoImage = NSImage(systemSymbolName: "arrow.uturn.forward", accessibilityDescription: "Redo") {
            redoButton.image = redoImage.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: Design.SymbolSize.actionButton, weight: .medium))
            redoButton.contentTintColor = .white
        }
        redoButton.widthAnchor.constraint(equalToConstant: 28).isActive = true
        redoButton.toolTip = "Redo (⇧⌘Z)"
        redoButton.target = self
        redoButton.action = #selector(redoTapped)
        redoButton.configureAsButton(label: "Redo", hint: "Redo last undone annotation (⇧⌘Z)")
        stackView.addArrangedSubview(redoButton)

        stackView.addArrangedSubview(createSeparator())

        let clearButton = NSButton()
        clearButton.bezelStyle = .texturedRounded
        clearButton.isBordered = false
        if let clearImage = NSImage(systemSymbolName: "trash", accessibilityDescription: "Clear") {
            clearButton.image = clearImage.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: Design.SymbolSize.actionButton, weight: .medium))
            clearButton.contentTintColor = .white
        }
        clearButton.widthAnchor.constraint(equalToConstant: 28).isActive = true
        clearButton.toolTip = "Clear All"
        clearButton.target = self
        clearButton.action = #selector(clearTapped)
        clearButton.configureAsButton(label: "Clear all", hint: "Remove all annotations from the overlay")
        stackView.addArrangedSubview(clearButton)

        refresh()
    }

    private func createSeparator() -> NSView {
        let sep = NSView()
        sep.wantsLayer = true
        sep.layer?.backgroundColor = Design.Color.glassBorder.cgColor
        sep.widthAnchor.constraint(equalToConstant: 1).isActive = true
        sep.heightAnchor.constraint(equalToConstant: 20).isActive = true
        sep.setAccessibilityElement(false)
        return sep
    }

    @objc private func toolSelected(_ sender: NSButton) {
        guard let tool = AnnotationTool(rawValue: sender.tag) else { return }
        annotationService.currentTool = tool
        refresh()
        AccessibilityAnnouncer.shared.announce("Selected \(tool.title) tool")
    }

    @objc private func openColorPanel() {
        let colorPanel = NSColorPanel.shared
        colorPanel.setTarget(self)
        colorPanel.setAction(#selector(colorPanelChanged(_:)))
        colorPanel.color = annotationService.strokeColor
        colorPanel.isContinuous = true
        colorPanel.makeKeyAndOrderFront(nil)
    }

    @objc private func colorPanelChanged(_ sender: NSColorPanel) {
        annotationService.strokeColor = sender.color
        colorWellButton.layer?.backgroundColor = sender.color.cgColor
    }

    @objc private func colorSelected(_ sender: NSButton) {
        guard let color = sender.layer?.backgroundColor.flatMap({ NSColor(cgColor: $0) }) else { return }
        annotationService.strokeColor = color
        colorWellButton.layer?.backgroundColor = color.cgColor
        refresh()
    }

    @objc private func strokeChanged(_ sender: NSSlider) {
        annotationService.strokeWidth = CGFloat(sender.doubleValue)
    }

    @objc private func undoTapped() {
        annotationService.undo()
        overlayWindow?.refreshAnnotationView()
        AccessibilityAnnouncer.shared.announce("Undone")
    }

    @objc private func redoTapped() {
        annotationService.redo()
        overlayWindow?.refreshAnnotationView()
        AccessibilityAnnouncer.shared.announce("Redone")
    }

    @objc private func clearTapped() {
        annotationService.clearAll()
        overlayWindow?.refreshAnnotationView()
        AccessibilityAnnouncer.shared.announce("All annotations cleared")
    }

    func refresh() {
        for (tool, button) in toolButtons {
            let isSelected = annotationService.currentTool == tool
            button.layer?.backgroundColor = isSelected
                ? Design.Color.glassBorder.cgColor
                : NSColor.clear.cgColor
            button.layer?.cornerRadius = Design.CornerRadius.small
            // Use accessibilityLabel to convey selected state (VoiceOver reads label)
            let label = isSelected ? "\(tool.title) (selected)" : tool.title
            button.setAccessibilityLabel(label)
            button.setAccessibilityRoleDescription("annotation tool")
        }
        undoButton.isEnabled = annotationService.undoManager.canUndo
        redoButton.isEnabled = annotationService.undoManager.canRedo
    }
}
