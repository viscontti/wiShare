import UIKit

/// Compact item row shown inside the wishlist editor sheet.
/// Tapping the row edits the item; the trailing button removes it.
final class WishlistItemSummaryView: UIControl {
    var onRemove: (() -> Void)?

    private let thumbnailView = UIImageView()
    private let titleLabel = UILabel()
    private let commentLabel = UILabel()
    private let removeButton = UIButton(type: .system)

    init(item: WishlistItem) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailView.backgroundColor = WishlistTheme.accentSoft
        thumbnailView.tintColor = WishlistTheme.accentDeep
        thumbnailView.clipsToBounds = true
        thumbnailView.layer.cornerRadius = 9
        thumbnailView.layer.cornerCurve = .continuous

        if let image = item.image {
            thumbnailView.image = image
            thumbnailView.contentMode = .scaleAspectFill
        } else {
            thumbnailView.image = UIImage(systemName: "photo")
            thumbnailView.contentMode = .center
        }

        titleLabel.text = item.title
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.adjustsFontForContentSizeCategory = true

        commentLabel.text = item.productURL?.host?.replacingOccurrences(of: "www.", with: "") ?? item.comment
        commentLabel.font = .preferredFont(forTextStyle: .caption1)
        commentLabel.adjustsFontForContentSizeCategory = true
        commentLabel.textColor = item.productURL == nil ? .secondaryLabel : WishlistTheme.accent
        commentLabel.isHidden = (commentLabel.text ?? "").isEmpty

        let textStack = UIStackView(arrangedSubviews: [titleLabel, commentLabel])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.isUserInteractionEnabled = false

        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.setImage(UIImage(systemName: "minus.circle.fill"), for: .normal)
        removeButton.tintColor = .systemRed
        removeButton.accessibilityLabel = "Remove \(item.title)"
        removeButton.setContentHuggingPriority(.required, for: .horizontal)
        removeButton.addTarget(self, action: #selector(remove), for: .touchUpInside)

        addSubview(thumbnailView)
        addSubview(textStack)
        addSubview(removeButton)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 56),

            thumbnailView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: WishlistTheme.Metrics.margin),
            thumbnailView.centerYAnchor.constraint(equalTo: centerYAnchor),
            thumbnailView.widthAnchor.constraint(equalToConstant: 38),
            thumbnailView.heightAnchor.constraint(equalToConstant: 38),

            textStack.leadingAnchor.constraint(equalTo: thumbnailView.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: removeButton.leadingAnchor, constant: -12),
            textStack.topAnchor.constraint(equalTo: topAnchor, constant: 9),
            textStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -9),

            removeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -WishlistTheme.Metrics.margin),
            removeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            removeButton.widthAnchor.constraint(equalToConstant: 28)
        ])
    }

    required init?(coder: NSCoder) { nil }

    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? .systemFill : .clear }
    }

    @objc private func remove() {
        onRemove?()
    }
}
