import AppKit
import UserNotifications
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.mark.macos", category: "AppDelegate")

class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayWindow: OverlayWindow!
    private var annotationService: AnnotationService!
    private var settingsStore: SettingsStore!
    private var exportService: ExportService!
    private var cloudExportService: CloudExportService!
    private var menuBarController: MenuBarController!
    private var hotKeyManager: HotKeyManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        settingsStore = SettingsStore()
        annotationService = AnnotationService(settings: settingsStore)

        overlayWindow = OverlayWindow(
            annotationService: annotationService,
            settings: settingsStore
        )
        overlayWindow.makeKeyAndOrderFront(nil)

        exportService = ExportService(annotationService: annotationService, overlayWindow: overlayWindow)

        // Menu bar
        menuBarController = MenuBarController(
            annotationService: annotationService,
            exportService: exportService,
            overlayWindow: overlayWindow
        )

        // Cloud export
        cloudExportService = CloudExportService()

        // Global hotkeys
        hotKeyManager = HotKeyManager.shared
        hotKeyManager.setCallback { [weak self] action in
            self?.handleHotkeyAction(action)
        }
        hotKeyManager.start()

        // Handle URL scheme
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        setupMenu()
        NSApp.setActivationPolicy(.accessory)

        // Show onboarding on first launch
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            showOnboarding()
        }
    }

    private func showOnboarding() {
        let onboarding = OnboardingViewController()
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = onboarding
        panel.title = "Welcome to Mark"
        panel.center()
        panel.isFloatingPanel = false
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else { return }

        switch url.host {
        case "open":
            overlayWindow.makeKeyAndOrderFront(nil)
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let fileItem = components.queryItems?.first(where: { $0.name == "file" }),
               let filePath = fileItem.value {
                logger.info("Opening file: \(filePath, privacy: .public)")
            }
        case "capture":
            exportService.captureScreen()
        default:
            break
        }
    }

    private func handleHotkeyAction(_ action: HotkeyAction) {
        switch action {
        case .toggleOverlay:
            if overlayWindow.isVisible {
                overlayWindow.orderOut(nil)
            } else {
                overlayWindow.makeKeyAndOrderFront(nil)
            }
        case .clearAnnotations:
            annotationService.clearAll()
            overlayWindow.refreshAnnotationView()
        case .undo:
            annotationService.undo()
            overlayWindow.refreshAnnotationView()
        case .redo:
            annotationService.redo()
            overlayWindow.refreshAnnotationView()
        case .captureScreen:
            exportService.captureScreen()
        case .selectArrow:
            annotationService.currentTool = .arrow
            overlayWindow.updateToolbar()
        case .selectRectangle:
            annotationService.currentTool = .rectangle
            overlayWindow.updateToolbar()
        case .selectText:
            annotationService.currentTool = .text
            overlayWindow.updateToolbar()
        case .selectFreehand:
            annotationService.currentTool = .freehand
            overlayWindow.updateToolbar()
        case .selectHighlighter:
            annotationService.currentTool = .highlighter
            overlayWindow.updateToolbar()
        }
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

        // File menu
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu

        let captureSubmenu = NSMenu(title: "Capture")
        let captureItem = NSMenuItem(title: "Capture", action: nil, keyEquivalent: "")
        captureItem.submenu = captureSubmenu
        fileMenu.addItem(captureItem)
        captureSubmenu.addItem(withTitle: "Capture Screen", action: #selector(captureScreen), keyEquivalent: "s")
        captureSubmenu.addItem(withTitle: "Capture Window", action: #selector(captureWindow), keyEquivalent: "W")

        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Export as PNG...", action: #selector(exportPNG), keyEquivalent: "e")
        fileMenu.addItem(withTitle: "Export as PDF...", action: #selector(exportPDF), keyEquivalent: "E")
        fileMenu.addItem(withTitle: "Copy to Clipboard", action: #selector(copyClipboard), keyEquivalent: "c")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Upload to Cloud...", action: #selector(uploadToCloud), keyEquivalent: "u")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Save Session...", action: #selector(saveSession), keyEquivalent: "S")
        fileMenu.addItem(withTitle: "Load Session...", action: #selector(loadSession), keyEquivalent: "l")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Sync from iCloud", action: #selector(syncFromICloud), keyEquivalent: "")

        // View menu
        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu

        viewMenu.addItem(withTitle: "Clear All Annotations", action: #selector(clearAnnotations), keyEquivalent: "k")
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(withTitle: "Undo", action: #selector(undoAction), keyEquivalent: "z")
        viewMenu.addItem(withTitle: "Redo", action: #selector(redoAction), keyEquivalent: "Z")
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

        settingsMenu.addItem(withTitle: "Keyboard Shortcuts...", action: #selector(showShortcutsSettings), keyEquivalent: ",")
        settingsMenu.addItem(withTitle: "Manage Presets...", action: #selector(showPresetManager), keyEquivalent: "")
        settingsMenu.addItem(NSMenuItem.separator())

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

    @objc private func undoAction() {
        annotationService.undo()
        overlayWindow.refreshAnnotationView()
    }

    @objc private func redoAction() {
        annotationService.redo()
        overlayWindow.refreshAnnotationView()
    }

    @objc private func captureScreen() {
        exportService.captureScreen()
    }

    @objc private func captureWindow() {
        exportService.captureWindow()
    }

    @objc private func exportPNG() {
        exportService.exportPNG()
    }

    @objc private func exportPDF() {
        exportService.exportPDF()
    }

    @objc private func copyClipboard() {
        exportService.copyToClipboard()
    }

    @objc private func uploadToCloud() {
        guard let image = exportService.renderAnnotatedImage() else { return }
        cloudExportService.uploadToCloud(image: image) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let url):
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url, forType: .string)
                    self.showNotification(title: "Uploaded!", message: "URL: \(url)")
                case .failure(let error):
                    self.showNotification(title: "Upload Failed", message: error.localizedDescription)
                }
            }
        }
    }

    private func showNotification(title: String, message: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = message
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            center.add(request)
        }
    }

    @objc private func showShortcutsSettings() {
        let vc = ShortcutsSettingsViewController()
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = vc
        panel.title = "Keyboard Shortcuts"
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func showPresetManager() {
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

    @objc private func saveSession() {
        let alert = NSAlert()
        alert.messageText = "Save Session"
        alert.informativeText = "Enter a name for this annotation session:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        textField.placeholderString = "Session name"
        alert.accessoryView = textField

        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn {
                    let name = textField.stringValue.isEmpty ? "Untitled" : textField.stringValue
                    do {
                        try self.annotationService.saveAnnotations(name: name)
                        self.showNotification(title: "Saved", message: "Session '\(name)' saved successfully.")
                    } catch {
                        self.showNotification(title: "Error", message: "Failed to save session.")
                    }
                }
            }
        }
    }

    @objc private func loadSession() {
        let sessions = annotationService.savedSessionNames
        guard !sessions.isEmpty else {
            showNotification(title: "No Sessions", message: "No saved sessions found.")
            return
        }

        let alert = NSAlert()
        alert.messageText = "Load Session"
        alert.informativeText = "Select a session to load:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Load")
        alert.addButton(withTitle: "Cancel")

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        for session in sessions {
            popup.addItem(withTitle: session)
        }
        alert.accessoryView = popup

        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn {
                    if let selected = popup.titleOfSelectedItem {
                        do {
                            try self.annotationService.loadAnnotations(name: selected)
                            self.overlayWindow.refreshAnnotationView()
                            self.showNotification(title: "Loaded", message: "Session '\(selected)' loaded.")
                        } catch {
                            self.showNotification(title: "Error", message: "Failed to load session.")
                        }
                    }
                }
            }
        }
    }

    @objc private func syncFromICloud() {
        AnnotationStorage.shared.syncFromICloud { [weak self] syncedNames in
            if syncedNames.isEmpty {
                self?.showNotification(title: "Sync Complete", message: "No new sessions found on iCloud.")
            } else {
                self?.showNotification(title: "Synced", message: "Synced \(syncedNames.count) session(s) from iCloud.")
            }
        }
    }
}

// MARK: - Annotation View

// MARK: - Toolbar View
