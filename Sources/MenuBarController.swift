import AppKit

class MenuBarController {
    private var statusItem: NSStatusItem!
    private let annotationService: AnnotationService
    private let exportService: ExportService
    private let overlayWindow: OverlayWindow

    init(annotationService: AnnotationService, exportService: ExportService, overlayWindow: OverlayWindow) {
        self.annotationService = annotationService
        self.exportService = exportService
        self.overlayWindow = overlayWindow
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "pencil.tip.crop.circle", accessibilityDescription: "Mark")
            button.image?.isTemplate = true
        }

        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(withTitle: "Show Overlay", action: #selector(showOverlay), keyEquivalent: "")
        menu.addItem(withTitle: "Hide Overlay", action: #selector(hideOverlay), keyEquivalent: "")

        menu.addItem(NSMenuItem.separator())

        let captureMenu = NSMenu(title: "Capture")
        let captureItem = menu.addItem(withTitle: "Capture", action: nil, keyEquivalent: "")
        captureItem.submenu = captureMenu
        captureMenu.addItem(withTitle: "Capture Screen", action: #selector(captureScreen), keyEquivalent: "")
        captureMenu.addItem(withTitle: "Capture Window", action: #selector(captureWindow), keyEquivalent: "")

        menu.addItem(NSMenuItem.separator())

        let toolsMenu = NSMenu(title: "Quick Tools")
        let toolsItem = menu.addItem(withTitle: "Quick Tools", action: nil, keyEquivalent: "")
        toolsItem.submenu = toolsMenu

        for tool in AnnotationTool.allCases {
            let item = NSMenuItem(title: tool.title, action: #selector(selectTool(_:)), keyEquivalent: "")
            item.tag = tool.rawValue
            item.target = self
            toolsMenu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let presetsMenu = NSMenu(title: "Presets")
        let presetsItem = menu.addItem(withTitle: "Presets", action: nil, keyEquivalent: "")
        presetsItem.submenu = presetsMenu

        let presetManager = PresetStore.shared
        for preset in presetManager.presets {
            let item = NSMenuItem(title: preset.name, action: #selector(applyPreset(_:)), keyEquivalent: "")
            item.representedObject = preset
            item.target = self
            presetsMenu.addItem(item)
        }

        if presetManager.presets.isEmpty {
            let noPresets = NSMenuItem(title: "No Presets", action: nil, keyEquivalent: "")
            noPresets.isEnabled = false
            presetsMenu.addItem(noPresets)
        }

        presetsMenu.addItem(NSMenuItem.separator())
        presetsMenu.addItem(withTitle: "Manage Presets...", action: #selector(managePresets), keyEquivalent: "")

        menu.addItem(NSMenuItem.separator())

        menu.addItem(withTitle: "Clear Annotations", action: #selector(clearAnnotations), keyEquivalent: "")

        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit Mark", action: #selector(quitApp), keyEquivalent: "")

        return menu
    }

    func rebuildMenu() {
        statusItem.menu = buildMenu()
    }

    @objc private func showOverlay() {
        overlayWindow.makeKeyAndOrderFront(nil)
    }

    @objc private func hideOverlay() {
        overlayWindow.orderOut(nil)
    }

    @objc private func captureScreen() {
        exportService.captureScreen()
    }

    @objc private func captureWindow() {
        exportService.captureWindow()
    }

    @objc private func selectTool(_ sender: NSMenuItem) {
        guard let tool = AnnotationTool(rawValue: sender.tag) else { return }
        annotationService.currentTool = tool
        overlayWindow.updateToolbar()
    }

    @objc private func applyPreset(_ sender: NSMenuItem) {
        guard let preset = sender.representedObject as? AnnotationPreset else { return }
        annotationService.strokeColor = preset.color
        annotationService.strokeWidth = preset.strokeWidth
        annotationService.currentTool = preset.tool
        overlayWindow.updateToolbar()
    }

    @objc private func managePresets() {
        let vc = PresetManagerViewController()
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = vc
        panel.title = "Manage Presets"
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func clearAnnotations() {
        annotationService.clearAll()
        overlayWindow.refreshAnnotationView()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - Preset Model

struct AnnotationPreset: Codable, Identifiable {
    let id: UUID
    var name: String
    var colorRed: CGFloat
    var colorGreen: CGFloat
    var colorBlue: CGFloat
    var colorAlpha: CGFloat
    var strokeWidth: CGFloat
    var tool: AnnotationTool

    var color: NSColor {
        get { NSColor(red: colorRed, green: colorGreen, blue: colorBlue, alpha: colorAlpha) }
        set {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            newValue.usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
            colorRed = r; colorGreen = g; colorBlue = b; colorAlpha = a
        }
    }

    init(name: String, color: NSColor, strokeWidth: CGFloat, tool: AnnotationTool) {
        self.id = UUID()
        self.name = name
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.colorRed = r; self.colorGreen = g; self.colorBlue = b; self.colorAlpha = a
        self.strokeWidth = strokeWidth
        self.tool = tool
    }
}

// MARK: - Preset Store

class PresetStore: ObservableObject {
    static let shared = PresetStore()

    @Published var presets: [AnnotationPreset] = []

    private let presetsKey = "annotationPresets"
    private let fileManager = FileManager.default

    private var appSupportURL: URL {
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = urls[0].appendingPathComponent("Mark", isDirectory: true)
        try? fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport
    }

    private var presetsFileURL: URL {
        appSupportURL.appendingPathComponent("presets.json")
    }

    init() {
        loadPresets()
    }

    func loadPresets() {
        guard fileManager.fileExists(atPath: presetsFileURL.path) else {
            presets = defaultPresets()
            savePresets()
            return
        }

        do {
            let data = try Data(contentsOf: presetsFileURL)
            presets = try JSONDecoder().decode([AnnotationPreset].self, from: data)
        } catch {
            presets = defaultPresets()
        }
    }

    func savePresets() {
        do {
            let data = try JSONEncoder().encode(presets)
            try data.write(to: presetsFileURL)
        } catch {
            print("Failed to save presets: \(error)")
        }
    }

    func addPreset(name: String, color: NSColor, strokeWidth: CGFloat, tool: AnnotationTool) {
        let preset = AnnotationPreset(name: name, color: color, strokeWidth: strokeWidth, tool: tool)
        presets.append(preset)
        savePresets()
    }

    func removePreset(at index: Int) {
        guard index >= 0, index < presets.count else { return }
        presets.remove(at: index)
        savePresets()
    }

    func renamePreset(at index: Int, to name: String) {
        guard index >= 0, index < presets.count else { return }
        presets[index].name = name
        savePresets()
    }

    private func defaultPresets() -> [AnnotationPreset] {
        [
            AnnotationPreset(name: "Red Medium", color: Theme.Color.red, strokeWidth: 3.0, tool: .arrow),
            AnnotationPreset(name: "Yellow Thick", color: Theme.Color.yellow, strokeWidth: 5.0, tool: .highlighter),
            AnnotationPreset(name: "Blue Thin", color: Theme.Color.blue, strokeWidth: 2.0, tool: .freehand)
        ]
    }
}

// MARK: - Preset Manager View Controller

class PresetManagerViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private var tableView: NSTableView!
    private var presetStore = PresetStore.shared

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        let scrollView = NSScrollView(frame: NSRect(x: 16, y: 50, width: 368, height: 234))
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]

        tableView = NSTableView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = false
        tableView.headerView = nil

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("PresetColumn"))
        col.width = 350
        tableView.addTableColumn(col)

        scrollView.documentView = tableView
        view.addSubview(scrollView)

        let addButton = NSButton(title: "Add Current", target: self, action: #selector(addPreset))
        addButton.bezelStyle = .rounded
        addButton.frame = NSRect(x: 16, y: 12, width: 100, height: 28)
        view.addSubview(addButton)

        let removeButton = NSButton(title: "Remove", target: self, action: #selector(removePreset))
        removeButton.bezelStyle = .rounded
        removeButton.frame = NSRect(x: 124, y: 12, width: 80, height: 28)
        view.addSubview(removeButton)

        let doneButton = NSButton(title: "Done", target: self, action: #selector(done))
        doneButton.bezelStyle = .rounded
        doneButton.frame = NSRect(x: 312, y: 12, width: 72, height: 28)
        view.addSubview(doneButton)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return presetStore.presets.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let preset = presetStore.presets[row]

        let cellView = NSTableCellView()
        let textField = NSTextField(labelWithString: preset.name)
        textField.frame = NSRect(x: 8, y: 2, width: 200, height: 20)
        cellView.addSubview(textField)

        let swatch = NSView(frame: NSRect(x: 220, y: 4, width: 16, height: 16))
        swatch.wantsLayer = true
        swatch.layer?.backgroundColor = preset.color.cgColor
        swatch.layer?.cornerRadius = 3
        swatch.layer?.borderWidth = 1
        swatch.layer?.borderColor = NSColor.white.withAlphaComponent(0.3).cgColor
        cellView.addSubview(swatch)

        let toolLabel = NSTextField(labelWithString: preset.tool.title)
        toolLabel.frame = NSRect(x: 244, y: 2, width: 80, height: 20)
        toolLabel.textColor = .secondaryLabelColor
        cellView.addSubview(toolLabel)

        return cellView
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 24
    }

    @objc private func addPreset() {
        let alert = NSAlert()
        alert.messageText = "Save Preset"
        alert.informativeText = "Enter a name for this preset:"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        textField.placeholderString = "Preset name..."
        alert.accessoryView = textField

        if alert.runModal() == .alertFirstButtonReturn {
            let name = textField.stringValue.isEmpty ? "Untitled Preset" : textField.stringValue
            presetStore.addPreset(name: name, color: Theme.Color.red, strokeWidth: 3.0, tool: .arrow)
            tableView.reloadData()
        }
    }

    @objc private func removePreset() {
        let row = tableView.selectedRow
        guard row >= 0 else { return }
        presetStore.removePreset(at: row)
        tableView.reloadData()
    }

    @objc private func done() {
        view.window?.close()
    }
}
