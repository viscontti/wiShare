import UIKit

/// Row in the main list: tinted SF Symbol tile, title, subtitle, item badge.
final class WishlistCell: UITableViewCell {
    static let reuseIdentifier = "WishlistCell"

    private let iconContainer = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let commentLabel = UILabel()
    private let countLabel = PaddedLabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) { nil }

    private func setupViews() {
        backgroundColor = WishlistTheme.surface
        accessoryType = .disclosureIndicator

        let selectedBackground = UIView()
        selectedBackground.backgroundColor = WishlistTheme.accentSoft
        selectedBackgroundView = selectedBackground

        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.backgroundColor = WishlistTheme.accentSoft
        iconContainer.layer.cornerRadius = WishlistTheme.Metrics.tileCorner
        iconContainer.layer.cornerCurve = .continuous

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = WishlistTheme.accentDeep
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 19, weight: .medium)
        iconContainer.addSubview(iconView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .label

        commentLabel.translatesAutoresizingMaskIntoConstraints = false
        commentLabel.font = .preferredFont(forTextStyle: .subheadline)
        commentLabel.adjustsFontForContentSizeCategory = true
        commentLabel.textColor = .secondaryLabel
        commentLabel.numberOfLines = 2

        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.font = .preferredFont(forTextStyle: .caption1)
        countLabel.adjustsFontForContentSizeCategory = true
        countLabel.textColor = WishlistTheme.accentDeep
        countLabel.backgroundColor = WishlistTheme.accentSoft
        countLabel.textAlignment = .center
        countLabel.insets = UIEdgeInsets(top: 3, left: 9, bottom: 3, right: 9)
        countLabel.layer.cornerRadius = 9
        countLabel.layer.cornerCurve = .continuous
        countLabel.clipsToBounds = true
        countLabel.setContentHuggingPriority(.required, for: .horizontal)
        countLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, commentLabel, countLabel])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4
        textStack.setCustomSpacing(8, after: commentLabel)

        contentView.addSubview(iconContainer)
        contentView.addSubview(textStack)

        NSLayoutConstraint.activate([
            iconContainer.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            iconContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            iconContainer.widthAnchor.constraint(equalToConstant: WishlistTheme.Metrics.tile),
            iconContainer.heightAnchor.constraint(equalToConstant: WishlistTheme.Metrics.tile),
            iconContainer.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12),

            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 14),
            textStack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            textStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    func configure(with wishlist: Wishlist) {
        iconView.image = UIImage(systemName: wishlist.symbolName) ?? UIImage(systemName: WishlistTheme.defaultSymbol)
        titleLabel.text = wishlist.title
        commentLabel.text = wishlist.comment
        commentLabel.isHidden = wishlist.comment.isEmpty
        countLabel.text = wishlist.itemCountText
        accessibilityLabel = "\(wishlist.title), \(wishlist.itemCountText)"
    }
}

/// Label with content insets, used for the item-count chip.
final class PaddedLabel: UILabel {
    var insets: UIEdgeInsets = .zero {
        didSet { invalidateIntrinsicContentSize() }
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + insets.left + insets.right,
            height: size.height + insets.top + insets.bottom
        )
    }
}
