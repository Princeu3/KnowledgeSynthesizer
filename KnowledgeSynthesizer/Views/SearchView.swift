import SwiftUI
import SwiftData

struct SearchView: View {
    @Query(sort: \KnowledgeItem.ingestedAt, order: .reverse) private var allItems: [KnowledgeItem]
    @State private var searchText = ""
    @State private var debouncedQuery = ""

    private var searchResults: [KnowledgeItem] {
        guard !debouncedQuery.isEmpty else { return [] }
        let query = debouncedQuery.lowercased()
        return allItems.filter { $0.searchableText.lowercased().contains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !searchResults.isEmpty {
                    Section("\(searchResults.count) results") {
                        ForEach(searchResults) { item in
                            NavigationLink(value: item.id) {
                                FeedRow(item: item)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Search")
            .navigationDestination(for: UUID.self) { id in
                if let item = allItems.first(where: { $0.id == id }) {
                    ItemDetailView(item: item)
                }
            }
            .searchable(text: $searchText, prompt: "Search your knowledge...")
            .task(id: searchText) {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                debouncedQuery = searchText
            }
            .overlay {
                if searchText.isEmpty {
                    ContentUnavailableView(
                        "Search Knowledge",
                        systemImage: "magnifyingglass",
                        description: Text("\(allItems.count) items indexed")
                    )
                } else if debouncedQuery == searchText && searchResults.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
    }
}

#Preview {
    SearchView()
        .modelContainer(for: KnowledgeItem.self, inMemory: true)
}
