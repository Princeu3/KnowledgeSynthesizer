import SwiftUI
import SwiftData

struct FeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \KnowledgeItem.ingestedAt, order: .reverse) private var items: [KnowledgeItem]
    @State private var selectedSourceFilter: SourceType?

    var filteredItems: [KnowledgeItem] {
        guard let filter = selectedSourceFilter else { return items }
        return items.filter { $0.sourceType == filter }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    emptyState
                } else {
                    itemList
                }
            }
            .navigationTitle("Knowledge")
            .task {
                // Import items shared via Share Extension
                importShareExtensionItems()
                // Enrich any pending items
                EnrichmentService.shared.processPendingItems(in: modelContext)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                importShareExtensionItems()
                EnrichmentService.shared.processPendingItems(in: modelContext)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    sourceFilterMenu
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Knowledge Yet",
            systemImage: "brain.head.profile",
            description: Text("Share links from any app or paste content to start building your knowledge base.")
        )
    }

    private var itemList: some View {
        List {
            ForEach(filteredItems) { item in
                NavigationLink(destination: ItemDetailView(item: item)) {
                    KnowledgeItemRow(item: item)
                }
            }
            .onDelete(perform: deleteItems)
        }
        .listStyle(.plain)
    }

    private var sourceFilterMenu: some View {
        Menu {
            Button("All Sources") {
                selectedSourceFilter = nil
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
            Image(systemName: selectedSourceFilter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
        }
    }

    private func importShareExtensionItems() {
        do {
            let pendingItems = try AppGroupManager.consumePendingItems()
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
        } catch {
            print("Failed to import share extension items: \(error)")
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = filteredItems[index]
            modelContext.delete(item)
        }
    }
}

struct KnowledgeItemRow: View {
    let item: KnowledgeItem

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail or source icon
            if let thumbnailURL = item.thumbnailURL, let url = URL(string: thumbnailURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    sourceIcon
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                sourceIcon
            }

            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(item.title.isEmpty ? "Untitled" : item.title)
                    .font(.headline)
                    .lineLimit(1)

                // Content preview
                if !item.content.isEmpty {
                    Text(item.content)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Metadata row
                HStack(spacing: 8) {
                    Text(item.sourceType.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: item.sourceType.accentColorHex))
                        .clipShape(Capsule())

                    Text(item.ingestedAt.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    if item.isEnriched {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    } else if item.processingStatus == "processing" {
                        ProgressView()
                            .controlSize(.mini)
                    } else if item.processingStatus == "failed" {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var sourceIcon: some View {
        Image(systemName: item.sourceType.iconName)
            .font(.title2)
            .foregroundStyle(Color(hex: item.sourceType.accentColorHex))
            .frame(width: 56, height: 56)
            .background(Color(hex: item.sourceType.accentColorHex).opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    FeedView()
        .modelContainer(for: KnowledgeItem.self, inMemory: true)
}
