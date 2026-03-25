import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Entry Point

@main
struct MarkWidgetBundle: WidgetBundle {
    var body: some Widget {
        MarkQuickStartWidget()
    }
}

// MARK: - App Intents (Widget-local)

struct OpenMarkIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Mark"
    static var description = IntentDescription("Opens the Mark overlay")

    func perform() async throws -> some IntentResult {
        // Open Mark via URL scheme
        if let url = URL(string: "mark://open") {
            NSWorkspace.shared.open(url)
        }
        return .result()
    }
}

struct CaptureScreenIntent: AppIntent {
    static var title: LocalizedStringResource = "Capture Screen"
    static var description = IntentDescription("Capture the screen with Mark")

    func perform() async throws -> some IntentResult {
        if let url = URL(string: "mark://capture") {
            NSWorkspace.shared.open(url)
        }
        return .result()
    }
}

struct OpenFileIntent: AppIntent {
    static var title: LocalizedStringResource = "Open File in Mark"
    static var description = IntentDescription("Opens a file for annotation")

    @Parameter(title: "File Path")
    var filePath: String

    init() {
        self.filePath = ""
    }

    init(filePath: String) {
        self.filePath = filePath
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        if let encoded = filePath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "mark://open?file=\(encoded)") {
            NSWorkspace.shared.open(url)
        }
        return .result(value: "Opened \(filePath)")
    }
}

// MARK: - Timeline Provider

struct MarkQuickStartProvider: TimelineProvider {
    func placeholder(in context: Context) -> MarkQuickStartEntry {
        MarkQuickStartEntry(date: Date(), recentFiles: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (MarkQuickStartEntry) -> Void) {
        let entry = MarkQuickStartEntry(date: Date(), recentFiles: getRecentFiles())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MarkQuickStartEntry>) -> Void) {
        let entry = MarkQuickStartEntry(date: Date(), recentFiles: getRecentFiles())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func getRecentFiles() -> [String] {
        let defaults = UserDefaults(suiteName: "group.com.mark.macos")
        return defaults?.stringArray(forKey: "recentFiles") ?? []
    }
}

// MARK: - Timeline Entry

struct MarkQuickStartEntry: TimelineEntry {
    let date: Date
    let recentFiles: [String]
}

// MARK: - Widget Views

struct MarkQuickStartWidget: Widget {
    let kind: String = "MarkQuickStartWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MarkQuickStartProvider()) { entry in
            MarkWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Mark Quick Start")
        .description("Quickly start presentations and capture screens.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct MarkWidgetEntryView: View {
    var entry: MarkQuickStartProvider.Entry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        default:
            smallWidget
        }
    }

    var smallWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "pencil.tip.crop.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Mark")
                    .font(.headline)
                    .fontWeight(.bold)
            }

            Spacer()

            Button(intent: OpenMarkIntent()) {
                Label("Start", systemImage: "play.fill")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)

            Button(intent: CaptureScreenIntent()) {
                Label("Capture", systemImage: "camera.fill")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    var mediumWidget: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "pencil.tip.crop.circle")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("Mark")
                        .font(.headline)
                        .fontWeight(.bold)
                }

                Spacer()

                Button(intent: OpenMarkIntent()) {
                    Label("Start", systemImage: "play.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                Button(intent: CaptureScreenIntent()) {
                    Label("Capture", systemImage: "camera.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Recent")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if entry.recentFiles.isEmpty {
                    Text("No recent files")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(entry.recentFiles.prefix(3), id: \.self) { file in
                        Button(intent: OpenFileIntent(filePath: file)) {
                            HStack {
                                Image(systemName: "doc.fill")
                                    .font(.caption2)
                                Text(fileName(from: file))
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func fileName(from path: String) -> String {
        return (path as NSString).lastPathComponent
    }
}
