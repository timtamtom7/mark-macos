import Foundation

// MARK: - Mark R12-R15 Models

struct MarkProject: Identifiable, Codable {
    let id: UUID
    var name: String
    var annotations: [MarkAnnotation]
    var createdAt: Date
    var sharedWith: [String]

    init(
        id: UUID = UUID(),
        name: String,
        annotations: [MarkAnnotation] = [],
        createdAt: Date = Date(),
        sharedWith: [String] = []
    ) {
        self.id = id
        self.name = name
        self.annotations = annotations
        self.createdAt = createdAt
        self.sharedWith = sharedWith
    }
}

struct MarkAnnotation: Identifiable, Codable {
    let id: UUID
    var content: String
    var type: AnnotationType
    var tags: [String]
    var createdAt: Date

    enum AnnotationType: String, Codable {
        case highlight
        case note
        case bookmark
        case screenshot
    }

    init(
        id: UUID = UUID(),
        content: String,
        type: AnnotationType = .highlight,
        tags: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.type = type
        self.tags = tags
        self.createdAt = createdAt
    }
}

struct SharedAnnotation: Identifiable, Codable {
    let id: UUID
    var annotationId: UUID
    var shareCode: String
    var expiresAt: Date?

    init(
        id: UUID = UUID(),
        annotationId: UUID,
        shareCode: String = String(UUID().uuidString.prefix(8)).uppercased(),
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.annotationId = annotationId
        self.shareCode = shareCode
        self.expiresAt = expiresAt
    }
}

struct ExportPreset: Identifiable, Codable {
    let id: UUID
    var name: String
    var format: ExportFormat
    var includeMetadata: Bool

    enum ExportFormat: String, Codable {
        case markdown
        case pdf
        case json
        case html
    }

    init(
        id: UUID = UUID(),
        name: String,
        format: ExportFormat = .markdown,
        includeMetadata: Bool = true
    ) {
        self.id = id
        self.name = name
        self.format = format
        self.includeMetadata = includeMetadata
    }
}
