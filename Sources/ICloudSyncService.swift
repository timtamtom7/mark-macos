import Foundation

class ICloudSyncService {
    static let shared = ICloudSyncService()

    private let fileManager = FileManager.default
    private var ubiquitousContainerURL: URL?

    private let presetsFileName = "presetsicloud.json"
    private let syncQueue = DispatchQueue(label: "com.mark.icloud.sync", qos: .utility)

    var isICloudAvailable: Bool {
        return ubiquitousContainerURL != nil
    }

    init() {
        ubiquitousContainerURL = fileManager.url(forUbiquityContainerIdentifier: "iCloud.com.mark.macos")
    }

    // MARK: - Sync Presets

    func syncPresets(_ presets: [AnnotationPreset], completion: @escaping ([AnnotationPreset]) -> Void) {
        guard let containerURL = ubiquitousContainerURL else {
            completion(presets)
            return
        }

        let presetsURL = containerURL.appendingPathComponent(presetsFileName)

        syncQueue.async { [weak self] in
            guard let self = self else { return }

            // Write local presets to iCloud
            do {
                let data = try JSONEncoder().encode(presets)
                try data.write(to: presetsURL)
            } catch {
                print("ICloud sync write error: \(error)")
            }

            // Read remote presets from iCloud
            do {
                if self.fileManager.fileExists(atPath: presetsURL.path) {
                    let remoteData = try Data(contentsOf: presetsURL)
                    let remotePresets = try JSONDecoder().decode([AnnotationPreset].self, from: remoteData)

                    // Merge: last-write-wins based on UUID
                    let merged = self.mergePresets(local: presets, remote: remotePresets)

                    DispatchQueue.main.async {
                        completion(merged)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(presets)
                    }
                }
            } catch {
                print("ICloud sync read error: \(error)")
                DispatchQueue.main.async {
                    completion(presets)
                }
            }
        }
    }

    private func mergePresets(local: [AnnotationPreset], remote: [AnnotationPreset]) -> [AnnotationPreset] {
        var merged: [UUID: AnnotationPreset] = [:]

        // Add all remote
        for preset in remote {
            merged[preset.id] = preset
        }

        // Override with local if newer (same ID = same preset)
        for preset in local {
            merged[preset.id] = preset
        }

        return Array(merged.values).sorted { $0.name < $1.name }
    }

    // MARK: - NSUbiquitousKeyValueStore fallback

    func saveToUbiquitousStore(key: String, data: Data) {
        let store = NSUbiquitousKeyValueStore.default
        store.set(data, forKey: key)
        store.synchronize()
    }

    func loadFromUbiquitousStore(key: String) -> Data? {
        let store = NSUbiquitousKeyValueStore.default
        store.synchronize()
        return store.data(forKey: key)
    }
}
