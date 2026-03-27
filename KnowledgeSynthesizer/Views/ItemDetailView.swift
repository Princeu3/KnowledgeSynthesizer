import SwiftUI

struct ItemDetailView: View {
    let item: KnowledgeItem
    @State private var showFullContent = false

    private var sourceColor: Color {
        item.sourceType.accentColor
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection

                if let analysis = item.visionAnalysis, !analysis.isEmpty {
                    takeawaysSection(analysis)
                }

                if !item.content.isEmpty {
                    contentSection
                }

                if !item.topics.isEmpty || !item.entities.isEmpty {
                    tagsSection
                }

                metadataSection

                if let urlString = item.sourceURL, let url = URL(string: urlString) {
                    Link(destination: url) {
                        Label("Open Original", systemImage: "arrow.up.right.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(sourceColor)
                }
            }
            .padding()
        }
        .navigationTitle("Detail")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let thumbnailURL = item.thumbnailURL, let url = URL(string: thumbnailURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    case .failure:
                        EmptyView()
                    default:
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.quaternary)
                            .frame(height: 200)
                            .overlay { ProgressView() }
                    }
                }
            }

            if !item.title.isEmpty {
                Text(item.title)
                    .font(.title2.weight(.bold))
            }

            HStack {
                Label(item.sourceType.displayName, systemImage: item.sourceType.iconName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(sourceColor, in: Capsule())

                Spacer()

                Text(item.ingestedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()
        }
    }

    // MARK: - Key Takeaways

    private func takeawaysSection(_ analysis: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Key Takeaways", systemImage: "sparkles")
                .font(.headline)

            let bullets = analysis
                .split(separator: "\n")
                .map(String.init)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(bullets.enumerated()), id: \.offset) { _, bullet in
                    let cleaned = bullet.hasPrefix("• ") ? String(bullet.dropFirst(2)) : bullet
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(sourceColor)
                            .frame(width: 6, height: 6)
                            .padding(.top, 7)
                        Text(cleaned)
                            .font(.body)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(sourceColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    // MARK: - Full Content

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy(duration: 0.3)) { showFullContent.toggle() }
            } label: {
                HStack {
                    Label(
                        showFullContent ? "Hide Details" : "Show Full Content",
                        systemImage: "chevron.down"
                    )
                    .font(.subheadline.weight(.medium))
                    .labelStyle(.titleAndIcon)
                    Spacer()
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            if showFullContent {
                Text(item.content)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Tags

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !item.entities.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mentioned").font(.headline)
                    FlowLayout(spacing: 6) {
                        ForEach(item.entities, id: \.self) { entity in
                            Text(entity)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(sourceColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(sourceColor.opacity(0.1), in: Capsule())
                        }
                    }
                }
            }

            if !item.topics.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Topics").font(.headline)
                    FlowLayout(spacing: 6) {
                        ForEach(item.topics, id: \.self) { topic in
                            Text(topic)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                }
            }
        }
    }

    // MARK: - Metadata

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

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + result.positions[index].x,
                    y: bounds.minY + result.positions[index].y
                ),
                proposal: .unspecified
            )
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
