import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var subscriptionManager: MarkSubscriptionManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab(settingsStore: settingsStore)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(0)

            AppearanceSettingsTab(settingsStore: settingsStore)
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
                .tag(1)

            ShortcutsSettingsTab()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
                .tag(2)

            SubscriptionSettingsTab(subscriptionManager: subscriptionManager)
                .tabItem {
                    Label("Subscription", systemImage: "creditcard")
                }
                .tag(3)

            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(4)
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

struct GeneralSettingsTab: View {
    @ObservedObject var settingsStore: SettingsStore
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showInMenuBar") private var showInMenuBar = true
    @AppStorage("captureOnLaunch") private var captureOnLaunch = false

    var body: some View {
        Form {
            Section {
                Toggle("Launch Mark at login", isOn: $launchAtLogin)
                Toggle("Show icon in menu bar", isOn: $showInMenuBar)
                Toggle("Capture screen on launch", isOn: $captureOnLaunch)
            } header: {
                Text("Startup")
            }

            Section {
                HStack {
                    Text("Default tool:")
                    Picker("", selection: $settingsStore.lastTool) {
                        ForEach(AnnotationTool.allCases, id: \.self) { tool in
                            Text(tool.title).tag(tool)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 120)
                }
            } header: {
                Text("Defaults")
            }

            Section {
                Button("Reset All Settings") {
                    resetSettings()
                }
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func resetSettings() {
        settingsStore.lastColor = Theme.Color.red
        settingsStore.lastStrokeWidth = 3.0
        settingsStore.lastTool = .arrow
        launchAtLogin = false
        showInMenuBar = true
        captureOnLaunch = false
    }
}

struct AppearanceSettingsTab: View {
    @ObservedObject var settingsStore: SettingsStore

    let presetColors: [NSColor] = [
        Theme.Color.red,
        Theme.Color.yellow,
        Theme.Color.green,
        Theme.Color.blue,
        Theme.Color.white,
        Theme.Color.orange,
        Theme.Color.purple
    ]

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Default Color")
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(32)), count: 7), spacing: 8) {
                        ForEach(presetColors, id: \.self) { color in
                            ColorButton(
                                color: color,
                                isSelected: settingsStore.lastColor == color
                            ) {
                                settingsStore.lastColor = color
                            }
                        }
                    }
                }
            } header: {
                Text("Colors")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Stroke Width: \(Int(settingsStore.lastStrokeWidth))")
                        Slider(value: $settingsStore.lastStrokeWidth, in: 1...10, step: 1)
                    }
                }
            } header: {
                Text("Stroke")
            }

            Section {
                Toggle("Use translucent toolbar", isOn: .constant(true))
                Toggle("Show tool tooltips", isOn: .constant(true))
            } header: {
                Text("Toolbar")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct ColorButton: View {
    let color: NSColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(color))
                .frame(width: 32, height: 32)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
                )
                .overlay(
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .opacity(isSelected ? 1 : 0)
                )
        }
        .buttonStyle(.plain)
    }
}

struct ShortcutsSettingsTab: View {
    @State private var bindings: [HotkeyBinding] = []

    var body: some View {
        Form {
            Section {
                Text("Configure keyboard shortcuts for Mark actions.")
                    .foregroundColor(.secondary)
            }

            Section {
                ForEach(bindings, id: \.action) { binding in
                    HStack {
                        Text(binding.action.displayName)
                            .frame(width: 180, alignment: .leading)
                        Text(binding.displayString)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(nsColor: .separatorColor).opacity(0.2))
                            .cornerRadius(4)
                        Spacer()
                    }
                }
            } header: {
                Text("Keyboard Shortcuts")
            }

            Section {
                Button("Reset to Defaults") {
                    resetShortcuts()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            bindings = HotKeyManager.shared.getAllBindings()
        }
    }

    private func resetShortcuts() {
        HotKeyManager.shared.loadBindings()
        bindings = HotKeyManager.shared.getAllBindings()
    }
}

struct SubscriptionSettingsTab: View {
    @ObservedObject var subscriptionManager: MarkSubscriptionManager
    @State private var isLoading = false

    var body: some View {
        Form {
            Section {
                if let subscription = subscriptionManager.subscription {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(subscription.tier.displayName)
                                .font(.headline)
                            Text(subscription.status.capitalized)
                                .font(.caption)
                                .foregroundColor(subscription.status == "active" ? .green : .orange)
                        }
                        Spacer()
                        if let expiresAt = subscription.expiresAt {
                            Text("Renews \(expiresAt, style: .date)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("No active subscription")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Current Plan")
            }

            Section {
                ForEach(subscriptionManager.products, id: \.id) { product in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(product.displayName)
                                .font(.headline)
                            Text(product.displayPrice)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Subscribe") {
                            // Handle subscription
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } header: {
                Text("Available Plans")
            }

            Section {
                Button("Restore Purchases") {
                    Task {
                        isLoading = true
                        try? await subscriptionManager.restore()
                        isLoading = false
                    }
                }
                .disabled(isLoading)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AboutTab: View {
    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "pencil.tip.crop.circle")
                        .font(.system(size: 64))
                        .foregroundColor(.accentColor)

                    VStack(alignment: .leading) {
                        Text("Mark")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }

            Section {
                Link(destination: URL(string: "https://mark.app")!) {
                    Label("Website", systemImage: "globe")
                }
                Link(destination: URL(string: "https://twitter.com/markapp")!) {
                    Label("Twitter", systemImage: "bird")
                }
                Link(destination: URL(string: "mailto:support@mark.app")!) {
                    Label("Contact", systemImage: "envelope")
                }
            }

            Section {
                Text("© 2024 Mark. All rights reserved.")
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

extension AnnotationTool: Hashable {}
