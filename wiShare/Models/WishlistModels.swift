import Foundation

/// How badly an item is wanted.
///
/// Raw values double as the grouping order: sorting by them yields the order
/// the sections appear in on screen and in the PDF, so nothing has to hold a
/// second list of "which priority comes first".
enum ItemPriority: Int, Codable, CaseIterable {
    case high = 0
    case medium = 1
    case low = 2

    /// Short label for pickers and menus.
    var title: String {
        switch self {
        case .high: "High"
        case .medium: "Medium"
        case .low: "Low"
        }
    }

    /// Heading above a group of items, on screen and in the PDF.
    var sectionTitle: String {
        "\(title) Priority".uppercased()
    }

    var symbolName: String {
        switch self {
        case .high: "chevron.up.2"
        case .medium: "equal"
        case .low: "chevron.down.2"
        }
    }
}

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

    /// Items of one priority, in stored order.
    ///
    /// `items` is kept grouped by `WishlistStore`, so this is a contiguous
    /// slice — a table section maps onto it one to one.
    func items(with priority: ItemPriority) -> [WishlistItem] {
        items.filter { $0.priority == priority }
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
    var priority: ItemPriority

    init(
        id: UUID = UUID(),
        photoFileName: String? = nil,
        title: String,
        comment: String = "",
        productURL: URL? = nil,
        priority: ItemPriority = .medium
    ) {
        self.id = id
        self.photoFileName = photoFileName
        self.title = title
        self.comment = comment
        self.productURL = productURL
        self.priority = priority
    }

    /// Items written before priorities existed carry no `priority` key. Decoded
    /// by hand so a missing one falls back to medium instead of failing the
    /// whole file — a throw here would leave the user with an empty app.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        photoFileName = try container.decodeIfPresent(String.self, forKey: .photoFileName)
        title = try container.decode(String.self, forKey: .title)
        comment = try container.decode(String.self, forKey: .comment)
        productURL = try container.decodeIfPresent(URL.self, forKey: .productURL)
        priority = try container.decodeIfPresent(ItemPriority.self, forKey: .priority) ?? .medium
    }
}
