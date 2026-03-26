import SwiftUI
import SwiftData

@main
struct KnowledgeSynthesizerApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([KnowledgeItem.self])
            let config = ModelConfiguration(
                "KnowledgeSynthesizer",
                schema: schema,
                groupContainer: .identifier("group.com.knowledgesynthesizer.shared")
            )
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
