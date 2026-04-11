import AppKit
import PDFKit
import UserNotifications
import os.log

private let logger = Logger(subsystem: "com.mark.macos", category: "ExportService")

class ExportService {
    private let annotationService: AnnotationService
    private let overlayWindow: OverlayWindow

    init(annotationService: AnnotationService, overlayWindow: OverlayWindow) {
        self.annotationService = annotationService
        self.overlayWindow = overlayWindow
    }

    // MARK: - PNG Export

    func exportPNG() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "Mark-\(dateString()).png"
        panel.canCreateDirectories = true

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.savePNG(to: url)
        }
    }

    private func savePNG(to url: URL) {
        guard let image = renderAnnotatedImage() else { return }

        if let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            try? pngData.write(to: url)
        }
    }

    // MARK: - PDF Export

    func exportPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "Mark-\(dateString()).pdf"
        panel.canCreateDirectories = true

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.savePDF(to: url)
        }
    }

    private func savePDF(to url: URL) {
        let pdfDoc = PDFDocument()
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

        // Single page for now — the overlay covers the whole screen
        _ = CGRect(origin: .zero, size: screenFrame.size)

        guard let image = renderAnnotatedImage() else {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Export Failed"
                alert.informativeText = "Could not capture screen. Please grant Screen Recording permission in System Settings > Privacy & Security > Screen Recording."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
            return
        }

        if let pdfPage = PDFPage(image: image) {
            pdfDoc.insert(pdfPage, at: 0)
            pdfDoc.write(to: url)
        }
    }

    // MARK: - Clipboard

    func copyToClipboard() {
        guard let image = renderAnnotatedImage() else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])

        // Also notify via notification
        showNotification(title: "Copied!", message: "Annotated image copied to clipboard.")
    }

    // MARK: - Screenshot Capture

    func captureScreen() {
        guard let screen = NSScreen.main else { return }
        let screenRect = screen.frame

        // Hide overlay briefly to capture clean screen
        overlayWindow.orderOut(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let cgImage = CGWindowListCreateImage(
                screenRect,
                .optionOnScreenOnly,
                kCGNullWindowID,
                [.bestResolution]
            ) else {
                self?.overlayWindow.makeKeyAndOrderFront(nil)
                return
            }

            let image = NSImage(cgImage: cgImage, size: screenRect.size)
            self?.overlayWindow.makeKeyAndOrderFront(nil)

            self?.showCapturePreview(image: image)
        }
    }

    func captureWindow() {
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

        var windows: [(id: CGWindowID, name: String, owner: String)] = []
        for info in windowList {
            guard let windowID = info[kCGWindowNumber as String] as? CGWindowID,
                  let ownerName = info[kCGWindowOwnerName as String] as? String,
                  let windowName = info[kCGWindowName as String] as? String,
                  !windowName.isEmpty else { continue }
            windows.append((windowID, windowName, ownerName))
        }

        showWindowPicker(windows: windows)
    }

    private func showWindowPicker(windows: [(id: CGWindowID, name: String, owner: String)]) {
        let alert = NSAlert()
        alert.messageText = "Select Window to Capture"
        alert.informativeText = ""
        alert.alertStyle = .informational

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        for window in windows {
            popup.addItem(withTitle: "\(window.owner): \(window.name)")
        }

        alert.accessoryView = popup
        alert.addButton(withTitle: "Capture")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let selectedIndex = popup.indexOfSelectedItem
            guard selectedIndex >= 0, selectedIndex < windows.count else { return }

            overlayWindow.orderOut(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let cgImage = CGWindowListCreateImage(
                    .null,
                    .optionIncludingWindow,
                    windows[selectedIndex].id,
                    [.bestResolution]
                ) else {
                    self?.overlayWindow.makeKeyAndOrderFront(nil)
                    return
                }

                let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                self?.overlayWindow.makeKeyAndOrderFront(nil)
                self?.showCapturePreview(image: image)
            }
        }
    }

    private func showCapturePreview(image: NSImage) {
        let vc = CapturePreviewViewController(image: image, annotationService: annotationService, overlayWindow: overlayWindow)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = vc
        panel.title = "Capture Preview"
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    // MARK: - Rendering

    func renderAnnotatedImage() -> NSImage? {
        guard let screen = NSScreen.main else { return nil }
        let screenRect = screen.frame

        let image = NSImage(size: screenRect.size)
        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return nil
        }

        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: screenRect.size))

        for annotation in annotationService.annotations {
            AnnotationRenderer.shared.draw(annotation, in: context)
        }

        image.unlockFocus()
        return image
    }

    // MARK: - Helpers

    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }

    private func showNotification(title: String, message: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = message
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                center.add(request)
            } else {
                // Fallback: show in-app alert when notifications are denied
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = title
                    alert.informativeText = message
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }
}

// MARK: - Capture Preview View Controller

class CapturePreviewViewController: NSViewController {
    private let image: NSImage
    private let annotationService: AnnotationService
    private let overlayWindow: OverlayWindow
    private var annotationLayer: AnnotationLayerView!

    init(image: NSImage, annotationService: AnnotationService, overlayWindow: OverlayWindow) {
        self.image = image
        self.annotationService = annotationService
        self.overlayWindow = overlayWindow
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let imageView = NSImageView(frame: view.bounds)
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.autoresizingMask = [.width, .height]
        view.addSubview(imageView)

        annotationLayer = AnnotationLayerView(frame: view.bounds, annotationService: annotationService)
        annotationLayer.autoresizingMask = [.width, .height]
        view.addSubview(annotationLayer)

        setupToolbar()
    }

    private func setupToolbar() {
        let toolbar = NSStackView()
        toolbar.orientation = .horizontal
        toolbar.spacing = Design.Spacing.buttonSpacing
        toolbar.edgeInsets = NSEdgeInsets(top: Design.Spacing.sm, left: Design.Spacing.toolbarPadding, bottom: Design.Spacing.sm, right: Design.Spacing.toolbarPadding)
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = Design.Color.background.cgColor
        toolbar.layer?.cornerRadius = Design.CornerRadius.medium
        view.addSubview(toolbar)

        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            toolbar.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
        ])

        let savePngBtn = NSButton(title: "Save PNG", target: self, action: #selector(savePNG))
        savePngBtn.bezelStyle = .rounded
        toolbar.addArrangedSubview(savePngBtn)

        let savePdfBtn = NSButton(title: "Save PDF", target: self, action: #selector(savePDF))
        savePdfBtn.bezelStyle = .rounded
        toolbar.addArrangedSubview(savePdfBtn)

        let copyBtn = NSButton(title: "Copy", target: self, action: #selector(copyClipboard))
        copyBtn.bezelStyle = .rounded
        toolbar.addArrangedSubview(copyBtn)

        let doneBtn = NSButton(title: "Done", target: self, action: #selector(done))
        doneBtn.bezelStyle = .rounded
        toolbar.addArrangedSubview(doneBtn)
    }

    @objc private func savePNG() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self = self else { return }
            self.savePNGTo(url)
        }
    }

    private func savePNGTo(_ url: URL) {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return }
        try? pngData.write(to: url)
    }

    @objc private func savePDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self = self else { return }
            self.savePDFTo(url)
        }
    }

    private func savePDFTo(_ url: URL) {
        let pdfDoc = PDFDocument()
        if let page = PDFPage(image: image) {
            pdfDoc.insert(page, at: 0)
            pdfDoc.write(to: url)
        }
    }

    @objc private func copyClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        view.window?.close()
    }

    @objc private func done() {
        view.window?.close()
    }
}

// MARK: - Annotation Layer View (for capture preview)

class AnnotationLayerView: NSView {
    private let annotationService: AnnotationService

    init(frame: NSRect, annotationService: AnnotationService) {
        self.annotationService = annotationService
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)

        for annotation in annotationService.annotations {
            AnnotationRenderer.shared.draw(annotation, in: context)
        }
    }
}
