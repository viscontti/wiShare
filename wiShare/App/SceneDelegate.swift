import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        // Global tint, so every control inherits the accent without extra wiring.
        window.tintColor = WishlistTheme.accent
        window.rootViewController = RootNavigationController()
        window.makeKeyAndVisible()
        self.window = window
    }
}
