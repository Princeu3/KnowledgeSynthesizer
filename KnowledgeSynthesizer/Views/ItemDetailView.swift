import SwiftUI

struct ItemDetailView: View {
    let item: KnowledgeItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                headerSection

                Divider()

                // Content
                if !item.content.isEmpty {
                    contentSection
                }

                // Vision Analysis
                if let analysis = item.visionAnalysis, !analysis.isEmpty {
                    visionAnalysisSection(analysis)
                }

                // Topics & Entities
                if !item.topics.isEmpty || !item.entities.isEmpty {
                    tagsSection
                }

                // Metadata
                metadataSection

                // Source link
                if let urlString = item.sourceURL, let url = URL(string: urlString) {
                    Link(destination: url) {
                        Label("Open Original", systemImage: "arrow.up.right.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .navigationTitle(item.title.isEmpty ? "Detail" : item.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            if let thumbnailURL = item.thumbnailURL, let url = URL(string: thumbnailURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(.quaternary)
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay {
                            ProgressView()
                        }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Title
            if !item.title.isEmpty {
                Text(item.title)
                    .font(.title2)
                    .fontWeight(.bold)
            }

            // Source badge + date
            HStack {
                Label(item.sourceType.displayName, systemImage: item.sourceType.iconName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: item.sourceType.accentColorHex))
                    .clipShape(Capsule())

                Spacer()

                Text(item.ingestedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Processing status
            if !item.isEnriched && item.processingStatus != "pending" {
                Label(item.processingStatus.capitalized, systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Content")
                .font(.headline)

            Text(item.content)
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }

    private func visionAnalysisSection(_ analysis: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("AI Visual Analysis", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(.yellow)

            Text(analysis)
                .font(.body)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !item.topics.isEmpty {
                Text("Topics")
                    .font(.headline)
                FlowLayout(spacing: 6) {
                    ForEach(item.topics, id: \.self) { topic in
                        Text(topic)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
            }

            if !item.entities.isEmpty {
                Text("Entities")
                    .font(.headline)
                FlowLayout(spacing: 6) {
                    ForEach(item.entities, id: \.self) { entity in
                        Text(entity)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.green.opacity(0.1))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }
            }

            if !item.tags.isEmpty {
                Text("Tags")
                    .font(.headline)
                FlowLayout(spacing: 6) {
                    ForEach(item.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.purple.opacity(0.1))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Details")
                .font(.headline)

            if let category = item.category {
                LabeledContent("Category", value: category)
            }
            if let contentDate = item.contentDate {
                LabeledContent("Content Date", value: contentDate.formatted(date: .abbreviated, time: .omitted))
            }
            LabeledContent("Ingested", value: item.ingestedAt.formatted(date: .abbreviated, time: .shortened))
            LabeledContent("Status", value: item.processingStatus.capitalized)
        }
        .font(.subheadline)
    }
}

/// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return (CGSize(width: maxX, height: currentY + lineHeight), positions)
    }
}
