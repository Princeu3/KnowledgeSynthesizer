import Foundation
import SwiftData

/// Automatically enriches KnowledgeItems by calling the backend extraction API
@MainActor
final class EnrichmentService {
    static let shared = EnrichmentService()

    private var isProcessing = false

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

                item.title = result.title
                item.content = result.content
                item.thumbnailURL = result.thumbnailURL
                item.visionAnalysis = result.visionAnalysis
                item.topics = result.topics
                item.entities = result.entities
                item.category = result.category
                item.contentDate = result.contentDate.flatMap { ISO8601DateFormatter().date(from: $0) }
                item.processingStatus = "enriched"
                item.isEnriched = true

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
