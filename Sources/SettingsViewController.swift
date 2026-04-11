import AppKit
import SwiftUI

class SettingsViewController: NSViewController {
    private let settingsStore: SettingsStore
    private let subscriptionManager: MarkSubscriptionManager

    init(settingsStore: SettingsStore, subscriptionManager: MarkSubscriptionManager) {
        self.settingsStore = settingsStore
        self.subscriptionManager = subscriptionManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let settingsView = SettingsView(
            settingsStore: settingsStore,
            subscriptionManager: subscriptionManager
        )
        let hostingController = NSHostingController(rootView: settingsView)
        self.view = hostingController.view
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.frame.size = NSSize(width: 500, height: 400)
    }
}
