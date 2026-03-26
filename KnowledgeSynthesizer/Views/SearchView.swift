import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \KnowledgeItem.ingestedAt, order: .reverse) private var allItems: [KnowledgeItem]
    @State private var searchText = ""

    var searchResults: [KnowledgeItem] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        return allItems.filter { item in
            item.searchableText.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    searchPrompt
                } else if searchResults.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    resultsList
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search your knowledge...")
        }
    }

    private var searchPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Search across all your saved knowledge")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(allItems.count) items indexed")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var resultsList: some View {
        List {
            Section("\(searchResults.count) results") {
                ForEach(searchResults) { item in
                    NavigationLink(destination: ItemDetailView(item: item)) {
                        KnowledgeItemRow(item: item)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

#Preview {
    SearchView()
        .modelContainer(for: KnowledgeItem.self, inMemory: true)
}
