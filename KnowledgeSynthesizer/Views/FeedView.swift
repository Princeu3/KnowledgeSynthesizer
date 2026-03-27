import SwiftUI
import SwiftData

struct FeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \KnowledgeItem.ingestedAt, order: .reverse) private var items: [KnowledgeItem]
    @State private var selectedSourceFilter: SourceType?

    private var filteredItems: [KnowledgeItem] {
        guard let filter = selectedSourceFilter else { return items }
        return items.filter { $0.sourceType == filter }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredItems) { item in
                    NavigationLink(value: item.id) {
                        FeedRow(item: item)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .listStyle(.plain)
            .navigationTitle("Knowledge")
            .navigationDestination(for: UUID.self) { id in
                if let item = items.first(where: { $0.id == id }) {
                    ItemDetailView(item: item)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    sourceFilterMenu
                }
            }
            .refreshable {
                importShareExtensionItems()
                EnrichmentService.shared.processPendingItems(in: modelContext)
            }
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No Knowledge Yet",
                        systemImage: "brain.head.profile",
                        description: Text("Share links from any app or paste content to start building your knowledge base.")
                    )
                }
            }
            .task {
                importShareExtensionItems()
                EnrichmentService.shared.processPendingItems(in: modelContext)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                importShareExtensionItems()
                EnrichmentService.shared.processPendingItems(in: modelContext)
            }
        }
    }

    // MARK: - Filter Menu

    private var sourceFilterMenu: some View {
        Menu {
            Button {
                selectedSourceFilter = nil
            } label: {
                Label("All Sources", systemImage: "square.grid.2x2")
            }
            Divider()
            ForEach(SourceType.allCases) { source in
                Button {
                    selectedSourceFilter = source
                } label: {
                    Label(source.displayName, systemImage: source.iconName)
                }
            }
        } label: {
            Image(systemName: selectedSourceFilter == nil
                  ? "line.3.horizontal.decrease.circle"
                  : "line.3.horizontal.decrease.circle.fill")
        }
    }

    // MARK: - Actions

    private func deleteItems(at offsets: IndexSet) {
        let toDelete = offsets.map { filteredItems[$0] }
        for item in toDelete {
            modelContext.delete(item)
        }
    }

    private func importShareExtensionItems() {
        Task {
            let pendingItems: [PendingShareItem]
            do {
                pendingItems = try await Task.detached {
                    try AppGroupManager.consumePendingItems()
                }.value
            } catch {
                return
            }
            for pending in pendingItems {
                let item = KnowledgeItem(
                    sourceURL: pending.url,
                    sourceType: SourceType(rawValue: pending.sourceType) ?? .text,
                    title: pending.title ?? pending.url ?? "Shared Item",
                    content: pending.text ?? ""
                )
                modelContext.insert(item)
                EnrichmentService.shared.enrich(item, in: modelContext)
            }
        }
    }
}

// MARK: - Feed Row

struct FeedRow: View {
    let item: KnowledgeItem

    /// Prioritize AI summary over raw content for preview
    private var previewText: String {
        if let analysis = item.visionAnalysis, !analysis.isEmpty {
            let firstBullet = analysis.split(separator: "\n").first.map(String.init) ?? ""
            return firstBullet.hasPrefix("• ") ? String(firstBullet.dropFirst(2)) : firstBullet
        }
        if !item.content.isEmpty {
            return item.content
        }
        if let url = item.sourceURL {
            return url
        }
        return ""
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            sourceIcon

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title.isEmpty ? "Untitled" : item.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if !previewText.isEmpty {
                    Text(previewText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 4) {
                    Text(item.sourceType.displayName)
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text("\u{00B7}")
                        .foregroundStyle(.quaternary)

                    Text(item.ingestedAt.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Spacer(minLength: 0)

                    statusIndicator
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(item.processingStatus == "processing" ? 0.7 : 1)
        .contentShape(Rectangle())
    }

    // MARK: - Source Icon (40x40 with enriched dot badge)

    private var sourceIcon: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(item.sourceType.accentColor.opacity(0.12))
            .frame(width: 40, height: 40)
            .overlay {
                Image(systemName: item.sourceType.iconName)
                    .font(.body)
                    .foregroundStyle(item.sourceType.accentColor)
            }
            .overlay(alignment: .topTrailing) {
                if item.isEnriched {
                    Circle()
                        .fill(item.sourceType.accentColor)
                        .frame(width: 8, height: 8)
                        .offset(x: 3, y: -3)
                }
            }
    }

    // MARK: - Status (only show for states needing attention)

    @ViewBuilder
    private var statusIndicator: some View {
        if item.processingStatus == "processing" {
            ProgressView()
                .controlSize(.mini)
        } else if item.processingStatus == "failed" {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(.red)
        }
    }
}

#Preview {
    FeedView()
        .modelContainer(for: KnowledgeItem.self, inMemory: true)
}
