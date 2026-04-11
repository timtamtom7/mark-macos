import Foundation
import os.log

private let logger = Logger(subsystem: "com.mark.macos", category: "AnnotationStorage")

final class AnnotationStorage {
    static let shared = AnnotationStorage()

    private let fileManager = FileManager.default
    private let annotationsKey = "savedAnnotations"

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var annotationsDirectory: URL {
        documentsDirectory.appendingPathComponent("MarkAnnotations", isDirectory: true)
    }

    private var iCloudContainerURL: URL? {
        fileManager.url(forUbiquityContainerIdentifier: "iCloud.com.mark.macos")
    }

    private var iCloudAnnotationsDirectory: URL? {
        iCloudContainerURL?.appendingPathComponent("Documents/MarkAnnotations", isDirectory: true)
    }

    var isICloudAvailable: Bool {
        iCloudContainerURL != nil
    }

    private init() {
        createDirectoryIfNeeded()
        createiCloudDirectoryIfNeeded()
    }

    private func createDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: annotationsDirectory.path) {
            try? fileManager.createDirectory(at: annotationsDirectory, withIntermediateDirectories: true)
        }
    }

    private func createiCloudDirectoryIfNeeded() {
        guard let iCloudDir = iCloudAnnotationsDirectory else { return }
        if !fileManager.fileExists(atPath: iCloudDir.path) {
            try? fileManager.createDirectory(at: iCloudDir, withIntermediateDirectories: true)
        }
    }

    func save(_ annotations: [Annotation], name: String, syncToICloud: Bool = true) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(annotations)
        let fileURL = annotationsDirectory.appendingPathComponent("\(name).json")
        try data.write(to: fileURL)

        if syncToICloud, let iCloudDir = iCloudAnnotationsDirectory {
            let iCloudFileURL = iCloudDir.appendingPathComponent("\(name).json")
            try? data.write(to: iCloudFileURL)
        }
    }

    func load(name: String) throws -> [Annotation] {
        if let iCloudDir = iCloudAnnotationsDirectory {
            let iCloudFileURL = iCloudDir.appendingPathComponent("\(name).json")
            if let iCloudData = try? Data(contentsOf: iCloudFileURL),
               let localData = try? Data(contentsOf: annotationsDirectory.appendingPathComponent("\(name).json")) {
                let iCloudDate = (try? fileManager.attributesOfItem(atPath: iCloudFileURL.path)[.modificationDate] as? Date) ?? Date.distantPast
                let localDate = (try? fileManager.attributesOfItem(atPath: annotationsDirectory.appendingPathComponent("\(name).json").path)[.modificationDate] as? Date) ?? Date.distantPast

                if iCloudDate > localDate {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    return try decoder.decode([Annotation].self, from: iCloudData)
                }
            }
        }

        let fileURL = annotationsDirectory.appendingPathComponent("\(name).json")
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Annotation].self, from: data)
    }

    func listSavedAnnotations() -> [String] {
        var localFiles = (try? fileManager.contentsOfDirectory(atPath: annotationsDirectory.path)) ?? []
        localFiles.append(contentsOf: (try? fileManager.contentsOfDirectory(atPath: iCloudAnnotationsDirectory?.path ?? "")) ?? [])

        return Array(Set(localFiles))
            .filter { $0.hasSuffix(".json") }
            .map { String($0.dropLast(5)) }
    }

    func delete(name: String) throws {
        let fileURL = annotationsDirectory.appendingPathComponent("\(name).json")
        try? fileManager.removeItem(at: fileURL)

        if let iCloudDir = iCloudAnnotationsDirectory {
            let iCloudFileURL = iCloudDir.appendingPathComponent("\(name).json")
            try? fileManager.removeItem(at: iCloudFileURL)
        }
    }

    func syncFromICloud(completion: @escaping ([String]) -> Void) {
        guard let iCloudDir = iCloudAnnotationsDirectory else {
            completion([])
            return
        }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            var syncedNames: [String] = []

            if let iCloudFiles = try? self.fileManager.contentsOfDirectory(atPath: iCloudDir.path) {
                for file in iCloudFiles where file.hasSuffix(".json") {
                    let name = String(file.dropLast(5))
                    if let iCloudData = try? Data(contentsOf: iCloudDir.appendingPathComponent(file)) {
                        let localURL = self.annotationsDirectory.appendingPathComponent(file)
                        let localDate = (try? self.fileManager.attributesOfItem(atPath: localURL.path)[.modificationDate] as? Date) ?? Date.distantPast
                        let iCloudDate = (try? self.fileManager.attributesOfItem(atPath: iCloudDir.appendingPathComponent(file).path)[.modificationDate] as? Date) ?? Date.distantPast

                        if iCloudDate > localDate {
                            try? iCloudData.write(to: localURL)
                            syncedNames.append(name)
                        }
                    }
                }
            }

            DispatchQueue.main.async {
                completion(syncedNames)
            }
        }
    }
}

struct AnnotationSession: Codable {
    let id: UUID
    let name: String
    let createdAt: Date
    let annotations: [Annotation]
}
