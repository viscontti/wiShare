import LinkPresentation
import UIKit

/// Pulls the preview image (and title) a product page advertises through its
/// Open Graph tags, using the same system parser as Messages link previews.
final class LinkMetadataService {
    struct Preview {
        let image: UIImage?
        let title: String?
    }

    private var provider: LPMetadataProvider?

    deinit {
        provider?.cancel()
    }

    /// Fetches metadata for `url`. The completion always lands on the main
    /// queue, and reports `nil` when the page exposes no preview at all.
    func fetchPreview(for url: URL, completion: @escaping (Preview?) -> Void) {
        cancel()

        // LPMetadataProvider is single-use — a fresh one per fetch is required.
        let provider = LPMetadataProvider()
        provider.timeout = 10
        self.provider = provider

        provider.startFetchingMetadata(for: url) { metadata, error in
            guard error == nil, let metadata else {
                Self.finish(with: nil, completion: completion)
                return
            }

            let title = metadata.title

            guard let imageProvider = metadata.imageProvider,
                  imageProvider.canLoadObject(ofClass: UIImage.self)
            else {
                Self.finish(with: Preview(image: nil, title: title), completion: completion)
                return
            }

            imageProvider.loadObject(ofClass: UIImage.self) { object, _ in
                Self.finish(with: Preview(image: object as? UIImage, title: title), completion: completion)
            }
        }
    }

    func cancel() {
        provider?.cancel()
        provider = nil
    }

    private static func finish(with preview: Preview?, completion: @escaping (Preview?) -> Void) {
        DispatchQueue.main.async { completion(preview) }
    }
}
