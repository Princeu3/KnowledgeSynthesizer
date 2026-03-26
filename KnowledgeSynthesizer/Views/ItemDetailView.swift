import SwiftUI

struct ItemDetailView: View {
    let item: KnowledgeItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                Divider()

                // Summary bullets (primary content)
                if let analysis = item.visionAnalysis, !analysis.isEmpty {
                    summarySection(analysis)
                }

                // Full content (transcript, caption) - collapsible
                if !item.content.isEmpty {
                    contentSection
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
        .navigationTitle("Detail")
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
                        .overlay { ProgressView() }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Title
            if !item.title.isEmpty {
                Text(item.title)
                    .font(.title3)
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
        }
    }

    private func summarySection(_ analysis: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Key Takeaways", systemImage: "sparkles")
                .font(.headline)

            let bullets = analysis.split(separator: "\n").map(String.init)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(bullets, id: \.self) { bullet in
                    let cleaned = bullet.hasPrefix("• ") ? String(bullet.dropFirst(2)) : bullet
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(.blue)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                        Text(cleaned)
                            .font(.body)
                    }
                }
            }
            .padding()
            .background(.blue.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    @State private var showFullContent = false

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { showFullContent.toggle() }
            } label: {
                HStack {
                    Label(showFullContent ? "Hide Details" : "Show Full Content", systemImage: showFullContent ? "chevron.up" : "chevron.down")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                }
                .foregroundStyle(.secondary)
            }

            if showFullContent {
                Text(item.content)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !item.entities.isEmpty {
                Text("Mentioned")
                    .font(.headline)
                FlowLayout(spacing: 6) {
                    ForEach(item.entities, id: \.self) { entity in
                        Text(entity)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
            }

            if !item.topics.isEmpty {
                Text("Topics")
                    .font(.headline)
                FlowLayout(spacing: 6) {
                    ForEach(item.topics, id: \.self) { topic in
                        Text(topic)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.gray.opacity(0.1))
                            .foregroundStyle(.secondary)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let category = item.category {
                LabeledContent("Category", value: category)
            }
            if let contentDate = item.contentDate {
                LabeledContent("Posted", value: contentDate.formatted(date: .abbreviated, time: .omitted))
            }
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
}

/// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
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
