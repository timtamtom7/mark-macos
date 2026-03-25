import AppKit
import Carbon

class ShortcutRecorderView: NSView {
    var action: HotkeyAction = .toggleOverlay
    var onShortcutChanged: ((UInt32, UInt32) -> Void)?

    private var isRecording = false
    private var recordedKeyCode: UInt32 = 0
    private var recordedModifiers: UInt32 = 0

    private let displayLabel = NSTextField(labelWithString: "")
    private let recordButton = NSButton(title: "Record", target: nil, action: nil)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        displayLabel.isEditable = false
        displayLabel.isBordered = false
        displayLabel.backgroundColor = .clear
        displayLabel.alignment = .center
        displayLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        displayLabel.textColor = .labelColor
        displayLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(displayLabel)

        recordButton.bezelStyle = .rounded
        recordButton.target = self
        recordButton.action = #selector(startRecording)
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(recordButton)

        NSLayoutConstraint.activate([
            displayLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            displayLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            displayLabel.widthAnchor.constraint(equalToConstant: 120),

            recordButton.leadingAnchor.constraint(equalTo: displayLabel.trailingAnchor, constant: 8),
            recordButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.cornerRadius = 4
    }

    func configure(action: HotkeyAction, keyCode: UInt32, modifiers: UInt32) {
        self.action = action
        self.recordedKeyCode = keyCode
        self.recordedModifiers = modifiers
        updateDisplay()
    }

    private func updateDisplay() {
        displayLabel.stringValue = HotkeyBinding(
            action: action,
            keyCode: recordedKeyCode,
            modifiers: recordedModifiers
        ).displayString
    }

    @objc private func startRecording() {
        isRecording = true
        recordButton.title = "Press key..."
        window?.makeFirstResponder(self)
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let keyCode = UInt32(event.keyCode)
        let modifiers = carbonModifiersFrom(event.modifierFlags)

        // Require at least one modifier
        if modifiers == 0 {
            NSSound.beep()
            return
        }

        recordedKeyCode = keyCode
        recordedModifiers = modifiers
        isRecording = false
        recordButton.title = "Record"
        updateDisplay()
        onShortcutChanged?(keyCode, modifiers)
    }

    override func flagsChanged(with event: NSEvent) {
        // Ignore during normal typing
    }
}

// MARK: - Shortcuts Settings View Controller

class ShortcutsSettingsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private var tableView: NSTableView!
    private var hotkeyManager = HotKeyManager.shared

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 400))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        let label = NSTextField(labelWithString: "Keyboard Shortcuts")
        label.font = NSFont.boldSystemFont(ofSize: 14)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        let scrollView = NSScrollView(frame: NSRect(x: 16, y: 50, width: 468, height: 334))
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]

        tableView = NSTableView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = false

        let actionCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Action"))
        actionCol.title = "Action"
        actionCol.width = 220
        tableView.addTableColumn(actionCol)

        let shortcutCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Shortcut"))
        shortcutCol.title = "Shortcut"
        shortcutCol.width = 200
        tableView.addTableColumn(shortcutCol)

        scrollView.documentView = tableView
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16)
        ])
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return HotkeyAction.allCases.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let action = HotkeyAction.allCases[row]
        let identifier = tableColumn?.identifier

        if identifier == NSUserInterfaceItemIdentifier("Action") {
            let cell = NSTextField(labelWithString: action.displayName)
            return cell
        } else if identifier == NSUserInterfaceItemIdentifier("Shortcut") {
            let cell = ShortcutRecorderView(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
            if let binding = hotkeyManager.getBinding(for: action) {
                cell.configure(action: action, keyCode: binding.keyCode, modifiers: binding.modifiers)
            }
            cell.onShortcutChanged = { [weak self] keyCode, modifiers in
                self?.hotkeyManager.updateBinding(action: action, keyCode: keyCode, modifiers: modifiers)
            }
            return cell
        }
        return nil
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 32
    }
}
