import Foundation

struct Wishlist: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var comment: String
    var symbolName: String
    var items: [WishlistItem]

    init(
        id: UUID = UUID(),
        title: String,
        comment: String = "",
        symbolName: String = WishlistTheme.defaultSymbol,
        items: [WishlistItem] = []
    ) {
        self.id = id
        self.title = title
        self.comment = comment
        self.symbolName = symbolName
        self.items = items
    }

    var itemCountText: String {
        items.count == 1 ? "1 item" : "\(items.count) items"
    }

    var photoFileNames: Set<String> {
        Set(items.compactMap(\.photoFileName))
    }
}

struct WishlistItem: Identifiable, Codable, Equatable {
    let id: UUID
    /// File name inside `PhotoStorage`, not the image itself — keeps the model
    /// small enough to serialise and send elsewhere.
    var photoFileName: String?
    var title: String
    var comment: String
    var productURL: URL?

    init(
        id: UUID = UUID(),
        photoFileName: String? = nil,
        title: String,
        comment: String = "",
        productURL: URL? = nil
    ) {
        self.id = id
        self.photoFileName = photoFileName
        self.title = title
        self.comment = comment
        self.productURL = productURL
    }
}
