import Foundation

protocol WishlistEditorDelegate: AnyObject {
    /// `editingID` is `nil` when the wishlist was just created.
    func wishlistEditor(_ editor: WishlistEditorViewController, didFinishWith wishlist: Wishlist, editingID: UUID?)
}

protocol WishlistItemEditorDelegate: AnyObject {
    /// `editingID` is `nil` when the item was just created.
    func wishlistItemEditor(_ editor: WishlistItemEditorViewController, didFinishWith item: WishlistItem, editingID: UUID?)
}
