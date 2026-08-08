import Foundation

/// Storage root shared by the app and the share extension.
///
/// The extension runs in its own sandbox and cannot see the app's `Documents`,
/// so everything both processes touch — wishlists, photos, the share inbox —
/// lives in the App Group container instead.
enum SharedContainer {
    static let appGroupIdentifier = "group.wishshare.wiShare"

    /// Falls back to the app's own Documents when the App Group is not
    /// provisioned, so the app keeps working standalone even if the entitlement
    /// is missing. The extension simply won't see anything in that case.
    static let root: URL = {
        if let shared = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) {
            return shared
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }()

    static var isUsingAppGroup: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) != nil
    }

    static func file(named name: String) -> URL {
        root.appendingPathComponent(name)
    }

    static func directory(named name: String) -> URL {
        let url = root.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
