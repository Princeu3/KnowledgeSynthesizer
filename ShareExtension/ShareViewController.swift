import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        handleSharedContent()
    }

    private func handleSharedContent() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            close()
            return
        }

        Task {
            var url: String?
            var text: String?
            var title: String?

            for item in extensionItems {
                // Try to get the attributed title
                if let attrTitle = item.attributedTitle?.string {
                    title = attrTitle
                }

                guard let attachments = item.attachments else { continue }

                for attachment in attachments {
                    // Handle URLs
                    if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                        if let data = try? await attachment.loadItem(forTypeIdentifier: UTType.url.identifier) {
                            if let sharedURL = data as? URL {
                                url = sharedURL.absoluteString
                            } else if let urlString = data as? String {
                                url = urlString
                            }
                        }
                    }

                    // Handle plain text
                    if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                        if let data = try? await attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier) {
                            if let sharedText = data as? String {
                                // If it looks like a URL, treat it as one
                                if sharedText.hasPrefix("http://") || sharedText.hasPrefix("https://") {
                                    url = url ?? sharedText
                                } else {
                                    text = sharedText
                                }
                            }
                        }
                    }
                }
            }

            // Save to shared container
            let pendingItem = PendingShareItem(
                url: url,
                text: text,
                title: title
            )

            do {
                try AppGroupManager.writePendingItem(pendingItem)
            } catch {
                print("Failed to save shared item: \(error)")
            }

            close()
        }
    }

    private func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
