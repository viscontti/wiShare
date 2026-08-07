import UIKit

struct Wishlist: Identifiable {
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
}

struct WishlistItem: Identifiable {
    let id: UUID
    var image: UIImage?
    var title: String
    var comment: String
    var productURL: URL?

    init(
        id: UUID = UUID(),
        image: UIImage? = nil,
        title: String,
        comment: String = "",
        productURL: URL? = nil
    ) {
        self.id = id
        self.image = image
        self.title = title
        self.comment = comment
        self.productURL = productURL
    }
}
