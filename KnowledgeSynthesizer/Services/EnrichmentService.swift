import Foundation
import SwiftData

/// Automatically enriches KnowledgeItems by calling the backend extraction API
@MainActor
final class EnrichmentService {
    static let shared = EnrichmentService()

    private var isProcessing = false
    private static let isoFormatter = ISO8601DateFormatter()

    /// Enrich a single item by calling the backend
    func enrich(_ item: KnowledgeItem, in context: ModelContext) {
        guard let url = item.sourceURL, !url.isEmpty else {
            item.processingStatus = "manual"
            item.isEnriched = true
            return
        }

        item.processingStatus = "processing"

        Task {
            do {
                let result = try await APIService.shared.extractInstagram(url: url)

                // Validate response — don't mark as enriched if backend returned garbage
                let titleIsURL = result.title.hasPrefix("http") || result.title.hasPrefix("Instagram: http")
                let hasRealContent = result.visionAnalysis != nil
                    || !result.topics.isEmpty
                    || (!result.content.isEmpty && !result.content.contains("Shared from Instagram:"))

                item.title = result.title
                item.content = result.content
                item.thumbnailURL = result.thumbnailURL
                item.visionAnalysis = result.visionAnalysis
                item.topics = result.topics
                item.entities = result.entities
                item.category = result.category
                item.contentDate = result.contentDate.flatMap { Self.isoFormatter.date(from: $0) }

                if titleIsURL && !hasRealContent {
                    item.processingStatus = "failed"
                    item.isEnriched = false
                } else {
                    item.processingStatus = "enriched"
                    item.isEnriched = true
                }

                if let meta = result.metadata {
                    let data = try JSONSerialization.data(withJSONObject: meta)
                    item.metadataJSON = String(data: data, encoding: .utf8)
                }

                try context.save()
            } catch {
                item.processingStatus = "failed"
                try? context.save()
            }
        }
    }

    /// Process all pending items in the database
    func processPendingItems(in context: ModelContext) {
        guard !isProcessing else { return }
        isProcessing = true

        let descriptor = FetchDescriptor<KnowledgeItem>(
            predicate: #Predicate { $0.processingStatus == "pending" }
        )

        do {
            let pendingItems = try context.fetch(descriptor)
            for item in pendingItems {
                enrich(item, in: context)
            }
        } catch {
            print("Failed to fetch pending items: \(error)")
        }

        isProcessing = false
    }
}
