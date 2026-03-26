import AppKit
import UserNotifications

// MARK: - Upload Provider Protocol

protocol UploadProvider {
    var name: String { get }
    func upload(image: NSImage, completion: @escaping (Result<String, Error>) -> Void)
}

// MARK: - Cloud Export Service

class CloudExportService {
    private var providers: [UploadProvider] = []
    private var selectedProvider: UploadProvider?

    init() {
        // Register providers
        let imgur = ImgurUploader()
        providers.append(imgur)
        selectedProvider = imgur
    }

    func setProvider(_ provider: UploadProvider) {
        selectedProvider = provider
    }

    func availableProviders() -> [UploadProvider] {
        return providers
    }

    func uploadToCloud(image: NSImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let provider = selectedProvider else {
            completion(.failure(CloudError.noProvider))
            return
        }

        provider.upload(image: image, completion: completion)
    }

    func showUploadMenu(from view: NSView, image: NSImage, exportService: ExportService) {
        let alert = NSAlert()
        alert.messageText = "Upload to Cloud"
        alert.informativeText = "Choose a service:"
        alert.alertStyle = .informational

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        for provider in providers {
            popup.addItem(withTitle: provider.name)
        }

        alert.accessoryView = popup
        alert.addButton(withTitle: "Upload")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            let index = popup.indexOfSelectedItem
            guard index >= 0, index < providers.count else { return }
            selectedProvider = providers[index]

            uploadToCloud(image: image) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let url):
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(url, forType: .string)
                        self?.showNotification(title: "Uploaded!", message: "URL copied to clipboard: \(url)")
                    case .failure(let error):
                        self?.showNotification(title: "Upload Failed", message: error.localizedDescription)
                    }
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
}

enum CloudError: LocalizedError {
    case noProvider
    case uploadFailed(String)
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .noProvider: return "No upload provider configured"
        case .uploadFailed(let msg): return "Upload failed: \(msg)"
        case .invalidImage: return "Could not create image data"
        }
    }
}
