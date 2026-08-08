//
//  wiShareApp.swift
//  wiShare
//
//  Created by n viscontti on 06.08.2026.
//
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        WishlistTheme.applyAppearance()

        // Pending shares first: their photos are already on disk and must be
        // referenced before the sweep below decides what is orphaned.
        let store = WishlistStore.shared
        store.applyPendingShares()

        // Photo files are written when picked, but the wishlist referencing them
        // is only committed on Done — cancelling leaves strays behind. Launch is
        // the one moment no editor can be holding an uncommitted file.
        store.pruneOrphanedPhotos()

        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}
