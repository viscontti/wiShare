import UIKit

/// Principal class of the share extension: hosts the capture form inside a
/// navigation bar so it reads like the rest of the app.
final class ShareNavigationController: UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()
        WishlistTheme.applyAppearance()
        view.tintColor = WishlistTheme.accent
        viewControllers = [ShareItemViewController()]
    }
}
