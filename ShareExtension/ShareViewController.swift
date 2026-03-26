import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private var hasProcessed = false

    override func viewDidLoad() {
        super.viewDidLoad()
        // Transparent — no UI shown, but view must go through full lifecycle
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Guard against multiple calls
        guard !hasProcessed else { return }
        hasProcessed = true

        // Capture extensionContext strongly before entering Task
        guard let extensionContext = self.extensionContext else { return }

        Task { @MainActor in
            do {
                try await self.processAndSave(extensionContext: extensionContext)
                extensionContext.completeRequest(returningItems: nil, completionHandler: nil)
            } catch {
                extensionContext.cancelRequest(withError: error)
            }
        }
    }

    private func processAndSave(extensionContext: NSExtensionContext) async throws {
        guard let extensionItems = extensionContext.inputItems as? [NSExtensionItem] else {
            return
        }

        var url: String?
        var text: String?
        var title: String?

        for item in extensionItems {
            if let attrTitle = item.attributedTitle?.string {
                title = attrTitle
            }

            guard let attachments = item.attachments else { continue }

            for attachment in attachments {
                // Handle URLs
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    let data = try await attachment.loadItem(forTypeIdentifier: UTType.url.identifier)
                    if let sharedURL = data as? URL {
                        url = sharedURL.absoluteString
                    } else if let urlString = data as? String {
                        url = urlString
                    }
                }

                // Handle plain text (only if we don't have a URL yet)
                if url == nil, attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    let data = try await attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier)
                    if let sharedText = data as? String {
                        if sharedText.hasPrefix("http://") || sharedText.hasPrefix("https://") {
                            url = sharedText
                        } else {
                            text = sharedText
                        }
                    }
                }
            }
        }

        // Only save if we got something
        guard url != nil || text != nil else { return }

        let pendingItem = PendingShareItem(url: url, text: text, title: title)
        try AppGroupManager.writePendingItem(pendingItem)
    }
}
