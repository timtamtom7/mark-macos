import WidgetKit
import SwiftUI
import AppIntents

@main
struct MarkWidgetBundle: WidgetBundle {
    var body: some Widget {
        MarkQuickStartWidget()
        MarkSessionsWidget()
    }
}

// MARK: - App Intents

struct OpenMarkIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Mark"
    static var description = IntentDescription("Opens the Mark overlay")
    static var openPaletteWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        if let url = URL(string: "mark://open") {
            NSWorkspace.shared.open(url)
        }
        return .result()
    }
}

struct CaptureScreenIntent: AppIntent {
    static var title: LocalizedStringResource = "Capture Screen"
    static var description = IntentDescription("Capture the screen with Mark")
    static var openPaletteWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        if let url = URL(string: "mark://capture") {
            NSWorkspace.shared.open(url)
        }
        return .result()
    }
}

struct LoadSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Load Session"
    static var description = IntentDescription("Loads a saved annotation session in Mark")
    
    @Parameter(title: "Session Name")
    var sessionName: String

    init() {
        self.sessionName = ""
    }

    init(sessionName: String) {
        self.sessionName = sessionName
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        if let encoded = sessionName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "mark://load?session=\(encoded)") {
            NSWorkspace.shared.open(url)
        }
        return .result(value: "Loaded \(sessionName)")
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

struct MarkQuickStartEntry: TimelineEntry {
    let date: Date
    let recentFiles: [String]
}

// MARK: - Sessions Provider

struct MarkSessionsProvider: TimelineProvider {
    func placeholder(in context: Context) -> MarkSessionEntry {
        MarkSessionEntry(date: Date(), sessions: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (MarkSessionEntry) -> Void) {
        let entry = MarkSessionEntry(date: Date(), sessions: getSessions())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MarkSessionEntry>) -> Void) {
        let entry = MarkSessionEntry(date: Date(), sessions: getSessions())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func getSessions() -> [String] {
        let defaults = UserDefaults(suiteName: "group.com.mark.macos")
        return defaults?.stringArray(forKey: "savedSessions") ?? []
    }
}

struct MarkSessionEntry: TimelineEntry {
    let date: Date
    let sessions: [String]
}

// MARK: - Widgets

struct MarkQuickStartWidget: Widget {
    let kind: String = "MarkQuickStartWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MarkQuickStartProvider()) { entry in
            MarkWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Mark")
        .description("Quickly start annotations and capture screens.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct MarkSessionsWidget: Widget {
    let kind: String = "MarkSessionsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MarkSessionsProvider()) { entry in
            MarkSessionsView(entry: entry)
        }
        .configurationDisplayName("Mark Sessions")
        .description("Access your saved annotation sessions.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - Widget Views

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
        VStack(alignment: .leading, spacing: 12) {
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
            VStack(alignment: .leading, spacing: 12) {
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
                Text("Recent Files")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if entry.recentFiles.isEmpty {
                    Text("No recent files")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(entry.recentFiles.prefix(3), id: \.self) { file in
                        HStack {
                            Image(systemName: "doc.fill")
                                .font(.caption2)
                            Text(fileName(from: file))
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func fileName(from path: String) -> String {
        (path as NSString).lastPathComponent
    }
}

struct MarkSessionsView: View {
    var entry: MarkSessionsProvider.Entry

    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.on.doc.fill")
                    .font(.title3)
                    .foregroundColor(.orange)
                Text("Sessions")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }

            if entry.sessions.isEmpty {
                VStack {
                    Spacer()
                    Text("No saved sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                    Text("Save your annotations to see them here")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                let displaySessions = family == .systemLarge ? entry.sessions.prefix(6) : entry.sessions.prefix(4)
                ForEach(Array(displaySessions), id: \.self) { session in
                    Button(intent: LoadSessionIntent(sessionName: session)) {
                        HStack {
                            Image(systemName: "rectangle.stack.fill")
                                .font(.caption)
                            Text(sessionName(from: session))
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    
                    if session != displaySessions.last {
                        Divider()
                    }
                }
                
                if family == .systemLarge && entry.sessions.count > 6 {
                    Spacer()
                    Text("+ \(entry.sessions.count - 6) more")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func sessionName(from path: String) -> String {
        (path as NSString).lastPathComponent.replacingOccurrences(of: ".json", with: "")
    }
}
