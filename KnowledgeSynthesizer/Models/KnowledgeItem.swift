import Foundation
import SwiftData

/// The core data model for a piece of ingested knowledge
@Model
final class KnowledgeItem {
    /// Unique identifier
    var id: UUID

    /// Original source URL (if any)
    var sourceURL: String?

    /// Type of source platform
    var sourceTypeRaw: String

    /// Title or headline
    var title: String

    /// Main text content (caption, article text, transcript, etc.)
    var content: String

    /// AI-generated visual analysis (from Gemini/Claude vision models)
    var visionAnalysis: String?

    /// AI-extracted topics/keywords
    var topics: [String]

    /// AI-extracted entities (people, brands, tools)
    var entities: [String]

    /// User-provided tags
    var tags: [String]

    /// Auto-assigned category/bucket
    var category: String?

    /// Thumbnail image URL
    var thumbnailURL: String?

    /// Source-specific metadata stored as JSON
    var metadataJSON: String?

    /// When the original content was created (if known)
    var contentDate: Date?

    /// When this item was ingested into the app
    var ingestedAt: Date

    /// Whether the backend has enriched this item
    var isEnriched: Bool

    /// Processing status: pending, processing, enriched, failed
    var processingStatus: String

    var sourceType: SourceType {
        get { SourceType(rawValue: sourceTypeRaw) ?? .text }
        set { sourceTypeRaw = newValue.rawValue }
    }

    init(
        sourceURL: String? = nil,
        sourceType: SourceType = .text,
        title: String = "",
        content: String = "",
        visionAnalysis: String? = nil,
        topics: [String] = [],
        entities: [String] = [],
        tags: [String] = [],
        category: String? = nil,
        thumbnailURL: String? = nil,
        metadataJSON: String? = nil,
        contentDate: Date? = nil
    ) {
        self.id = UUID()
        self.sourceURL = sourceURL
        self.sourceTypeRaw = sourceType.rawValue
        self.title = title
        self.content = content
        self.visionAnalysis = visionAnalysis
        self.topics = topics
        self.entities = entities
        self.tags = tags
        self.category = category
        self.thumbnailURL = thumbnailURL
        self.metadataJSON = metadataJSON
        self.contentDate = contentDate
        self.ingestedAt = Date()
        self.isEnriched = false
        self.processingStatus = "pending"
    }
}

extension KnowledgeItem {
    /// All searchable text combined
    var searchableText: String {
        var parts: [String] = [title, content]
        if let v = visionAnalysis { parts.append(v) }
        if let c = category { parts.append(c) }
        parts.append(contentsOf: topics)
        parts.append(contentsOf: entities)
        parts.append(contentsOf: tags)
        return parts.joined(separator: " ")
    }
}
