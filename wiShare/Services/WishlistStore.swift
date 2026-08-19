import Foundation

/// Keeps observers alive only as long as the observing object is; releasing the
/// token unsubscribes.
final class ObservationToken {
    private let cancellation: () -> Void

    init(_ cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    deinit {
        cancellation()
    }
}

/// Single source of truth for wishlists, persisted as JSON in Documents.
///
/// A plain file rather than UserDefaults: defaults are a property list loaded
/// wholesale at launch, which is the wrong place for growing user content.
///
/// Main-thread only — every caller is a view controller.
final class WishlistStore {
    static let shared = WishlistStore()

    private(set) var wishlists: [Wishlist] = []

    private let fileURL: URL
    private let photoStorage: PhotoStorage
    private var observers: [UUID: () -> Void] = [:]

    init(fileURL: URL? = nil, photoStorage: PhotoStorage = .shared) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.photoStorage = photoStorage
        load()
    }

    private static func defaultFileURL() -> URL {
        // Shared, so the extension can read the list of wishlists to pick from.
        SharedContainer.file(named: "wishlists.json")
    }

    // MARK: - Reading

    func wishlist(with id: UUID) -> Wishlist? {
        wishlists.first { $0.id == id }
    }

    // MARK: - Mutating

    func add(_ wishlist: Wishlist) {
        wishlists.insert(wishlist, at: 0)
        commit()
    }

    func update(_ wishlist: Wishlist) {
        guard let index = wishlists.firstIndex(where: { $0.id == wishlist.id }) else {
            add(wishlist)
            return
        }

        // Photos of items dropped during editing are no longer referenced.
        let removed = wishlists[index].photoFileNames.subtracting(wishlist.photoFileNames)
        removed.forEach(photoStorage.delete(named:))

        wishlists[index] = wishlist
        commit()
    }

    /// Moves an item into another priority, placing it at the end of that
    /// group — the caller never says *where* in the group, only *which*.
    func setPriority(_ priority: ItemPriority, forItemID itemID: UUID, inWishlistWithID wishlistID: UUID) {
        guard let listIndex = wishlists.firstIndex(where: { $0.id == wishlistID }),
              let itemIndex = wishlists[listIndex].items.firstIndex(where: { $0.id == itemID }),
              wishlists[listIndex].items[itemIndex].priority != priority
        else { return }

        var item = wishlists[listIndex].items.remove(at: itemIndex)
        item.priority = priority
        // Appending puts it last overall; the regroup in `commit` then pulls it
        // back to the end of its own group.
        wishlists[listIndex].items.append(item)
        commit()
    }

    func delete(id: UUID) {
        guard let index = wishlists.firstIndex(where: { $0.id == id }) else { return }

        wishlists[index].photoFileNames.forEach(photoStorage.delete(named:))
        wishlists.remove(at: index)
        commit()
    }

    /// Merges everything the share extension captured while the app was away.
    /// - Returns: how many items were added.
    @discardableResult
    func applyPendingShares() -> Int {
        let entries = ShareInbox.drain()
        guard !entries.isEmpty else { return 0 }

        for entry in entries {
            if let wishlistID = entry.wishlistID,
               let index = wishlists.firstIndex(where: { $0.id == wishlistID }) {
                wishlists[index].items.append(entry.item)
            } else {
                // Either a brand new list, or the chosen one was deleted since.
                let title = entry.newWishlistTitle ?? "Shared"
                wishlists.insert(Wishlist(title: title, items: [entry.item]), at: 0)
            }
        }

        commit()
        return entries.count
    }

    /// Drops photo files nothing references — run once at launch, when no
    /// editor can be holding a freshly written file that is not committed yet.
    func pruneOrphanedPhotos() {
        // The reference set is read here, on the store's own thread; only the
        // file scanning is handed off.
        let referenced = wishlists.reduce(into: Set<String>()) { result, wishlist in
            result.formUnion(wishlist.photoFileNames)
        }
        let storage = photoStorage

        DispatchQueue.global(qos: .utility).async {
            storage.deleteUnreferenced(keeping: referenced)
        }
    }

    // MARK: - Observation

    func observe(_ handler: @escaping () -> Void) -> ObservationToken {
        let id = UUID()
        observers[id] = handler
        return ObservationToken { [weak self] in
            self?.observers[id] = nil
        }
    }

    // MARK: - Persistence

    private func commit() {
        regroupItemsByPriority()
        save()
        observers.values.forEach { $0() }
    }

    /// Restores the one rule everything else leans on: every wishlist's items
    /// are laid out high → medium → low, keeping their relative order inside a
    /// group. A table section is then a contiguous slice of the array, and the
    /// PDF only has to watch for the priority changing as it walks it.
    ///
    /// Enforced here rather than at each call site, so it also holds for items
    /// arriving from the share extension and for lists saved before priorities
    /// existed.
    private func regroupItemsByPriority() {
        for index in wishlists.indices {
            let items = wishlists[index].items
            let grouped = ItemPriority.allCases.flatMap { priority in
                items.filter { $0.priority == priority }
            }

            guard grouped != items else { continue }
            wishlists[index].items = grouped
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(wishlists)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("Failed to persist wishlists: \(error)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        wishlists = (try? JSONDecoder().decode([Wishlist].self, from: data)) ?? []
        // Lists written before priorities existed are ungrouped on disk; group
        // them in memory so readers see the invariant even before a first save.
        regroupItemsByPriority()
    }
}
