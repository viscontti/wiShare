import UIKit

/// Row inside a wishlist: product thumbnail, name, note and a link hint.
final class WishlistItemCell: UITableViewCell {
    static let reuseIdentifier = "WishlistItemCell"

    private let thumbnailView = UIImageView()
    private let titleLabel = UILabel()
    private let commentLabel = UILabel()
    private let linkLabel = UILabel()
    private let linkIconView = UIImageView(image: UIImage(systemName: "link"))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) { nil }

    private func setupViews() {
        backgroundColor = WishlistTheme.surface

        let selectedBackground = UIView()
        selectedBackground.backgroundColor = WishlistTheme.accentSoft
        selectedBackgroundView = selectedBackground

        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailView.backgroundColor = WishlistTheme.accentSoft
        thumbnailView.tintColor = WishlistTheme.accentDeep
        thumbnailView.contentMode = .scaleAspectFill
        thumbnailView.clipsToBounds = true
        thumbnailView.layer.cornerRadius = WishlistTheme.Metrics.tileCorner
        thumbnailView.layer.cornerCurve = .continuous

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true

        commentLabel.translatesAutoresizingMaskIntoConstraints = false
        commentLabel.font = .preferredFont(forTextStyle: .subheadline)
        commentLabel.adjustsFontForContentSizeCategory = true
        commentLabel.textColor = .secondaryLabel
        commentLabel.numberOfLines = 2

        linkIconView.translatesAutoresizingMaskIntoConstraints = false
        linkIconView.tintColor = WishlistTheme.accent
        linkIconView.contentMode = .scaleAspectFit
        linkIconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .caption1)
        linkIconView.setContentHuggingPriority(.required, for: .horizontal)

        linkLabel.translatesAutoresizingMaskIntoConstraints = false
        linkLabel.font = .preferredFont(forTextStyle: .caption1)
        linkLabel.adjustsFontForContentSizeCategory = true
        linkLabel.textColor = WishlistTheme.accent
        linkLabel.lineBreakMode = .byTruncatingMiddle

        let linkStack = UIStackView(arrangedSubviews: [linkIconView, linkLabel])
        linkStack.axis = .horizontal
        linkStack.spacing = 5
        linkStack.alignment = .firstBaseline

        let textStack = UIStackView(arrangedSubviews: [titleLabel, commentLabel, linkStack])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 3
        textStack.setCustomSpacing(6, after: commentLabel)

        contentView.addSubview(thumbnailView)
        contentView.addSubview(textStack)

        NSLayoutConstraint.activate([
            thumbnailView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            thumbnailView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            thumbnailView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12),
            thumbnailView.widthAnchor.constraint(equalToConstant: WishlistTheme.Metrics.thumbnail),
            thumbnailView.heightAnchor.constraint(equalToConstant: WishlistTheme.Metrics.thumbnail),

            textStack.leadingAnchor.constraint(equalTo: thumbnailView.trailingAnchor, constant: 14),
            textStack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            textStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    func configure(with item: WishlistItem) {
        if let image = item.image {
            thumbnailView.image = image
            thumbnailView.contentMode = .scaleAspectFill
        } else {
            thumbnailView.image = UIImage(systemName: "photo")
            thumbnailView.contentMode = .center
        }

        titleLabel.text = item.title
        commentLabel.text = item.comment
        commentLabel.isHidden = item.comment.isEmpty

        if let host = item.productURL?.host {
            linkLabel.text = host.replacingOccurrences(of: "www.", with: "")
            linkIconView.isHidden = false
            linkLabel.isHidden = false
            accessoryType = .disclosureIndicator
            selectionStyle = .default
        } else {
            linkIconView.isHidden = true
            linkLabel.isHidden = true
            accessoryType = .none
            selectionStyle = .none
        }
    }
}
