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
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("wishlists.json")
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

    func delete(id: UUID) {
        guard let index = wishlists.firstIndex(where: { $0.id == id }) else { return }

        wishlists[index].photoFileNames.forEach(photoStorage.delete(named:))
        wishlists.remove(at: index)
        commit()
    }

    /// Drops photo files nothing references — run once at launch, when no
    /// editor can be holding a freshly written file that is not committed yet.
    func pruneOrphanedPhotos() {
        let referenced = wishlists.reduce(into: Set<String>()) { result, wishlist in
            result.formUnion(wishlist.photoFileNames)
        }
        photoStorage.deleteUnreferenced(keeping: referenced)
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
        save()
        observers.values.forEach { $0() }
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
    }
}
