import UIKit

final class RootNavigationController: UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()
        WishlistTheme.applyAppearance()
        navigationBar.prefersLargeTitles = true
        viewControllers = [WishlistListViewController()]
    }
}
