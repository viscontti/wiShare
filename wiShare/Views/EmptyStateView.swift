import UIKit

/// Centered placeholder shown when a list has no content, styled after the
/// system "content unavailable" look (large symbol, title, message, action).
final class EmptyStateView: UIView {
    private let stack = UIStackView()
    private let actionButton = UIButton(type: .system)
    private var action: (() -> Void)?
    
    init(symbolName: String, title: String, message: String, actionTitle:  String? = nil, newString: String = "") {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let imageView = UIImageView(
            image: UIImage(systemName: symbolName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 48, weight: .regular))
        )
        imageView.tintColor = WishlistTheme.accent.withAlphaComponent(0.55)
        imageView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .title3)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = .preferredFont(forTextStyle: .subheadline)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        stack.addArrangedSubview(imageView)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(messageLabel)
        stack.setCustomSpacing(14, after: imageView)
        addSubview(stack)

        if let actionTitle {
            var configuration = UIButton.Configuration.tinted()
            configuration.title = actionTitle
            configuration.image = UIImage(systemName: "plus")
            configuration.imagePadding = 6
            configuration.baseForegroundColor = WishlistTheme.accent
            configuration.baseBackgroundColor = WishlistTheme.accent
            configuration.cornerStyle = .large
            actionButton.configuration = configuration
            actionButton.addTarget(self, action: #selector(runAction), for: .touchUpInside)
            stack.setCustomSpacing(20, after: messageLabel)
            stack.addArrangedSubview(actionButton)
        }

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40)
        ])
    }

    required init?(coder: NSCoder) { nil }

    func onAction(_ handler: @escaping () -> Void) {
        action = handler
    }

    @objc private func runAction() {
        action?()
    }
}
