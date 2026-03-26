import Foundation

/// Manages shared data between the main app and Share Extension via App Groups
enum AppGroupManager {
    static let groupIdentifier = "group.com.knowledgesynthesizer.shared"

    static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)
    }

    /// Write a shared item from the Share Extension for the main app to pick up
    static func writePendingItem(_ item: PendingShareItem) throws {
        guard let containerURL = sharedContainerURL else {
            throw AppGroupError.containerNotFound
        }

        let pendingDir = containerURL.appendingPathComponent("pending", isDirectory: true)
        try FileManager.default.createDirectory(at: pendingDir, withIntermediateDirectories: true)

        let filename = "\(item.id.uuidString).json"
        let fileURL = pendingDir.appendingPathComponent(filename)

        let data = try JSONEncoder().encode(item)
        try data.write(to: fileURL)
    }

    /// Read and remove all pending items (called by main app)
    static func consumePendingItems() throws -> [PendingShareItem] {
        guard let containerURL = sharedContainerURL else {
            throw AppGroupError.containerNotFound
        }

        let pendingDir = containerURL.appendingPathComponent("pending", isDirectory: true)
        guard FileManager.default.fileExists(atPath: pendingDir.path) else {
            return []
        }

        let files = try FileManager.default.contentsOfDirectory(at: pendingDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }

        var items: [PendingShareItem] = []
        for file in files {
            let data = try Data(contentsOf: file)
            let item = try JSONDecoder().decode(PendingShareItem.self, from: data)
            items.append(item)
            try FileManager.default.removeItem(at: file)
        }

        return items
    }
}

/// Lightweight item passed from Share Extension to main app
struct PendingShareItem: Codable {
    let id: UUID
    let url: String?
    let text: String?
    let title: String?
    let sourceType: String
    let timestamp: Date

    init(url: String? = nil, text: String? = nil, title: String? = nil) {
        self.id = UUID()
        self.url = url
        self.text = text
        self.title = title
        self.sourceType = url.map { SourceType.detect(from: $0).rawValue } ?? SourceType.text.rawValue
        self.timestamp = Date()
    }
}

enum AppGroupError: LocalizedError {
    case containerNotFound

    var errorDescription: String? {
        switch self {
        case .containerNotFound: return "Shared container not available"
        }
    }
}
