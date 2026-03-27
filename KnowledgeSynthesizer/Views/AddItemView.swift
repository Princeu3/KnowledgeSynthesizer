import SwiftUI
import SwiftData

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var inputText = ""
    @State private var inputURL = ""
    @State private var selectedSource: SourceType = .text
    @State private var tags = ""
    @State private var showingConfirmation = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case url, content, tags }

    private var canSave: Bool {
        !inputText.isEmpty || !inputURL.isEmpty
    }

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

                Section("Link") {
                    TextField("https://...", text: $inputURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .url)
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
                        .focused($focusedField, equals: .content)
                }

                Section("Tags (comma separated)") {
                    TextField("ai, swift, design...", text: $tags)
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .tags)
                }
            }
            .navigationTitle("Add Knowledge")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: saveItem)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") { focusedField = nil }
                    }
                }
            }
            .alert("Saved", isPresented: $showingConfirmation) {
                Button("OK") { resetForm() }
            } message: {
                Text("Knowledge item saved successfully.")
            }
        }
    }

    // MARK: - Actions

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

        if !inputURL.isEmpty {
            item.processingStatus = "pending"
        } else {
            item.processingStatus = "manual"
            item.isEnriched = true
        }

        modelContext.insert(item)

        if !inputURL.isEmpty {
            EnrichmentService.shared.enrich(item, in: modelContext)
        }

        focusedField = nil
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
