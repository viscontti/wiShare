import Foundation

/// One item captured by the share extension, waiting to be merged into the
/// store the next time the app becomes active.
struct ShareInboxEntry: Codable, Identifiable {
    let id: UUID
    /// Existing wishlist to append to…
    var wishlistID: UUID?
    /// …or the name of a wishlist to create for it.
    var newWishlistTitle: String?
    var item: WishlistItem

    init(id: UUID = UUID(), wishlistID: UUID? = nil, newWishlistTitle: String? = nil, item: WishlistItem) {
        self.id = id
        self.wishlistID = wishlistID
        self.newWishlistTitle = newWishlistTitle
        self.item = item
    }
}

/// Hand-off point between the share extension and the app.
///
/// The extension deliberately never writes `wishlists.json`: two processes
/// rewriting the same file would silently lose each other's updates. It drops
/// one small file per captured item here, which is append-only by construction,
/// and the app drains the folder when it next becomes active.
enum ShareInbox {
    private static var directory: URL {
        SharedContainer.directory(named: "Inbox")
    }

    static func write(_ entry: ShareInboxEntry) throws {
        let data = try JSONEncoder().encode(entry)
        let url = directory.appendingPathComponent("\(entry.id.uuidString).json")
        try data.write(to: url, options: .atomic)
    }

    /// Returns everything waiting, oldest first, and clears the folder.
    static func drain() -> [ShareInboxEntry] {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else { return [] }

        let ordered = files
            .filter { $0.pathExtension == "json" }
            .sorted { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return lhsDate < rhsDate
            }

        var entries: [ShareInboxEntry] = []
        for file in ordered {
            defer { try? fileManager.removeItem(at: file) }

            guard let data = try? Data(contentsOf: file),
                  let entry = try? JSONDecoder().decode(ShareInboxEntry.self, from: data)
            else { continue } // Unreadable: drop it rather than retry forever.

            entries.append(entry)
        }
        return entries
    }
}
