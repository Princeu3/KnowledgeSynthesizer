import UIKit
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

        Task { @MainActor in
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
                        do {
                            let data = try await attachment.loadItem(forTypeIdentifier: UTType.url.identifier)
                            if let sharedURL = data as? URL {
                                url = sharedURL.absoluteString
                            } else if let urlString = data as? String {
                                url = urlString
                            }
                        } catch {
                            print("Failed to load URL: \(error)")
                        }
                    }

                    // Handle plain text
                    if url == nil, attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                        do {
                            let data = try await attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier)
                            if let sharedText = data as? String {
                                if sharedText.hasPrefix("http://") || sharedText.hasPrefix("https://") {
                                    url = sharedText
                                } else {
                                    text = sharedText
                                }
                            }
                        } catch {
                            print("Failed to load text: \(error)")
                        }
                    }
                }
            }

            // Save to shared container
            if url != nil || text != nil {
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
            }

            close()
        }
    }

    private func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
