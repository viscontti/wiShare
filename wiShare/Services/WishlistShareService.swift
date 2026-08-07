import UIKit

/// Builds the wishlist PDF and hands it to the system share sheet, where
/// Telegram, Mail, AirDrop and the rest register themselves automatically.
enum WishlistShareService {
    /// Where the popover should point on iPad.
    enum Anchor {
        case barButton(UIBarButtonItem)
        case view(UIView, CGRect)
    }

    static func share(_ wishlist: Wishlist, from presenter: UIViewController, anchor: Anchor) {
        // Rendering touches UIKit but not the view hierarchy, and stays off the
        // main thread so a list full of photos never blocks a tap.
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try WishlistPDFRenderer.writePDF(for: wishlist) }

            DispatchQueue.main.async {
                switch result {
                case .success(let url):
                    present(url: url, wishlist: wishlist, from: presenter, anchor: anchor)
                case .failure:
                    presentFailure(from: presenter)
                }
            }
        }
    }

    private static func present(
        url: URL,
        wishlist: Wishlist,
        from presenter: UIViewController,
        anchor: Anchor
    ) {
        let item = WishlistPDFActivityItem(fileURL: url, title: wishlist.title)
        let activityViewController = UIActivityViewController(
            activityItems: [item],
            applicationActivities: nil
        )
        activityViewController.completionWithItemsHandler = { _, completed, _, _ in
            guard completed else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }

        switch anchor {
        case .barButton(let barButtonItem):
            activityViewController.popoverPresentationController?.barButtonItem = barButtonItem
        case .view(let sourceView, let sourceRect):
            activityViewController.popoverPresentationController?.sourceView = sourceView
            activityViewController.popoverPresentationController?.sourceRect = sourceRect
        }

        presenter.present(activityViewController, animated: true)
    }

    private static func presentFailure(from presenter: UIViewController) {
        let alert = UIAlertController(
            title: "Couldn’t Create PDF",
            message: "Something went wrong while preparing the file. Please try again.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        presenter.present(alert, animated: true)
    }
}

/// Supplies the PDF plus a subject line and preview, so the share sheet and
/// the receiving app show the wishlist name rather than a raw file name.
private final class WishlistPDFActivityItem: NSObject, UIActivityItemSource {
    private let fileURL: URL
    private let title: String

    init(fileURL: URL, title: String) {
        self.fileURL = fileURL
        self.title = title
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        fileURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        fileURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        title
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        thumbnailImageForActivityType activityType: UIActivity.ActivityType?,
        suggestedSize size: CGSize
    ) -> UIImage? {
        WishlistPDFRenderer.thumbnail(ofPDFAt: fileURL, size: size)
    }
}
