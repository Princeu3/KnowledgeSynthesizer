import SwiftUI
import SwiftData

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var inputText = ""
    @State private var inputURL = ""
    @State private var selectedSource: SourceType = .text
    @State private var tags = ""
    @State private var showingConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Source") {
                    Picker("Platform", selection: $selectedSource) {
                        ForEach(SourceType.allCases) { source in
                            Label(source.displayName, systemImage: source.iconName)
                                .tag(source)
                        }
                    }
                }

                Section("Link (optional)") {
                    TextField("https://...", text: $inputURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: inputURL) { _, newValue in
                            if !newValue.isEmpty {
                                let detected = SourceType.detect(from: newValue)
                                if detected != .website || selectedSource == .text {
                                    selectedSource = detected
                                }
                            }
                        }
                }

                Section("Content") {
                    TextEditor(text: $inputText)
                        .frame(minHeight: 120)
                }

                Section("Tags (comma separated)") {
                    TextField("ai, swift, design...", text: $tags)
                        .textInputAutocapitalization(.never)
                }

                Section {
                    Button(action: saveItem) {
                        Label("Save Knowledge", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(inputText.isEmpty && inputURL.isEmpty)
                }
            }
            .navigationTitle("Add Knowledge")
            .alert("Saved", isPresented: $showingConfirmation) {
                Button("OK") { resetForm() }
            } message: {
                Text("Knowledge item saved successfully.")
            }
        }
    }

    private func saveItem() {
        let parsedTags = tags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let title = extractTitle()

        let item = KnowledgeItem(
            sourceURL: inputURL.isEmpty ? nil : inputURL,
            sourceType: selectedSource,
            title: title,
            content: inputText,
            tags: parsedTags
        )

        // If there's a URL, mark as pending for backend enrichment
        if !inputURL.isEmpty {
            item.processingStatus = "pending"
        } else {
            item.processingStatus = "manual"
            item.isEnriched = true
        }

        modelContext.insert(item)

        // Auto-enrich if there's a URL
        if !inputURL.isEmpty {
            EnrichmentService.shared.enrich(item, in: modelContext)
        }

        showingConfirmation = true
    }

    private func extractTitle() -> String {
        if !inputText.isEmpty {
            let firstLine = inputText.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? inputText
            return String(firstLine.prefix(80))
        }
        if !inputURL.isEmpty {
            return inputURL
        }
        return "Untitled"
    }

    private func resetForm() {
        inputText = ""
        inputURL = ""
        tags = ""
        selectedSource = .text
    }
}

#Preview {
    AddItemView()
        .modelContainer(for: KnowledgeItem.self, inMemory: true)
}
