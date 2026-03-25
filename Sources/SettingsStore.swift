import AppKit

class SettingsStore: ObservableObject {
    private let lastColorKey = "lastColor"
    private let lastStrokeWidthKey = "lastStrokeWidth"
    private let lastToolKey = "lastTool"

    var lastColor: NSColor {
        get {
            if let data = UserDefaults.standard.data(forKey: lastColorKey),
               let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
                return color
            }
            return Theme.Color.red
        }
        set {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true) {
                UserDefaults.standard.set(data, forKey: lastColorKey)
            }
        }
    }

    var lastStrokeWidth: CGFloat {
        get {
            let value = UserDefaults.standard.double(forKey: lastStrokeWidthKey)
            return value > 0 ? CGFloat(value) : 3.0
        }
        set {
            UserDefaults.standard.set(Double(newValue), forKey: lastStrokeWidthKey)
        }
    }

    var lastTool: AnnotationTool {
        get {
            let raw = UserDefaults.standard.integer(forKey: lastToolKey)
            return AnnotationTool(rawValue: raw) ?? .arrow
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: lastToolKey)
        }
    }
}
