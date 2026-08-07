import UIKit

/// Rounded card that mimics an inset-grouped table section: rows stacked
/// vertically with hairline separators inset from the leading edge.
final class FormSectionView: UIView {
    private let stack = UIStackView()

    init(rows: [UIView]) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = WishlistTheme.surface
        layer.cornerRadius = WishlistTheme.Metrics.corner
        layer.cornerCurve = .continuous
        clipsToBounds = true

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        setRows(rows)
    }

    required init?(coder: NSCoder) { nil }

    func setRows(_ rows: [UIView]) {
        stack.arrangedSubviews.forEach { view in
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for (index, row) in rows.enumerated() {
            if index > 0 {
                stack.addArrangedSubview(makeSeparator())
            }
            stack.addArrangedSubview(row)
        }
    }

    private func makeSeparator() -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        container.translatesAutoresizingMaskIntoConstraints = false

        let line = UIView()
        line.translatesAutoresizingMaskIntoConstraints = false
        line.backgroundColor = .separator
        container.addSubview(line)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
            line.topAnchor.constraint(equalTo: container.topAnchor),
            line.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            line.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: WishlistTheme.Metrics.margin),
            line.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        return container
    }
}

/// Uppercased footnote header shown above a section, matching Settings.
final class FormHeaderLabel: UILabel {
    init(_ title: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        text = title.uppercased()
        font = .preferredFont(forTextStyle: .footnote)
        adjustsFontForContentSizeCategory = true
        textColor = .secondaryLabel
        numberOfLines = 0
    }

    required init?(coder: NSCoder) { nil }

    /// Header wrapped in a container that supplies the padding an
    /// inset-grouped section header uses.
    static func wrapped(_ title: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let label = FormHeaderLabel(title)
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: WishlistTheme.Metrics.margin),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -WishlistTheme.Metrics.margin),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -7)
        ])
        return container
    }
}

/// Footnote shown under a section, for hints and validation copy.
final class FormFooterLabel: UILabel {
    init(_ text: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        self.text = text
        font = .preferredFont(forTextStyle: .footnote)
        adjustsFontForContentSizeCategory = true
        textColor = .secondaryLabel
        numberOfLines = 0
    }

    required init?(coder: NSCoder) { nil }

    static func wrapped(_ text: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let label = FormFooterLabel(text)
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: WishlistTheme.Metrics.margin),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -WishlistTheme.Metrics.margin),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 7),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }
}

/// Single-line text field row sized like a standard table row.
final class FormFieldRow: UIView {
    let textField = UITextField()

    init(placeholder: String, icon: String? = nil) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = placeholder
        textField.font = .preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        textField.borderStyle = .none
        textField.clearButtonMode = .whileEditing
        addSubview(textField)

        var leading = leadingAnchor.constraint(equalTo: textField.leadingAnchor, constant: -WishlistTheme.Metrics.margin)

        if let icon {
            let iconView = UIImageView(image: UIImage(systemName: icon))
            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.tintColor = WishlistTheme.accent
            iconView.contentMode = .scaleAspectFit
            addSubview(iconView)

            NSLayoutConstraint.activate([
                iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: WishlistTheme.Metrics.margin),
                iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 22)
            ])
            leading = textField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12)
        }

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: WishlistTheme.Metrics.rowHeight),
            leading,
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -WishlistTheme.Metrics.margin),
            textField.topAnchor.constraint(equalTo: topAnchor, constant: 11),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -11)
        ])
    }

    required init?(coder: NSCoder) { nil }

    /// Briefly flashes the row to point at a validation problem.
    func flagAsInvalid() {
        let original = backgroundColor
        UIView.animate(withDuration: 0.15, animations: {
            self.backgroundColor = UIColor.systemRed.withAlphaComponent(0.14)
        }, completion: { _ in
            UIView.animate(withDuration: 0.25, delay: 0.35) {
                self.backgroundColor = original
            }
        })
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

/// Multiline note row that grows with its content and shows a placeholder.
final class FormNoteRow: UIView, UITextViewDelegate {
    let textView = UITextView()
    private let placeholderLabel = UILabel()

    init(placeholder: String, minimumHeight: CGFloat = 88) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = false
        textView.delegate = self
        addSubview(textView)

        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.text = placeholder
        placeholderLabel.font = .preferredFont(forTextStyle: .body)
        placeholderLabel.adjustsFontForContentSizeCategory = true
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.numberOfLines = 0
        addSubview(placeholderLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: minimumHeight),

            textView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: WishlistTheme.Metrics.margin),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -WishlistTheme.Metrics.margin),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            placeholderLabel.trailingAnchor.constraint(equalTo: textView.trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { nil }

    var text: String {
        get { textView.text ?? "" }
        set {
            textView.text = newValue
            updatePlaceholder()
        }
    }

    private func updatePlaceholder() {
        placeholderLabel.isHidden = !(textView.text ?? "").isEmpty
    }

    func textViewDidChange(_ textView: UITextView) {
        updatePlaceholder()
    }
}

/// Tappable row with a leading symbol, used for "Add item" style actions.
final class FormActionRow: UIControl {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    init(title: String, symbolName: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = UIImage(systemName: symbolName)
        iconView.tintColor = WishlistTheme.accent
        iconView.contentMode = .scaleAspectFit

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = WishlistTheme.accent

        addSubview(iconView)
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: WishlistTheme.Metrics.rowHeight),

            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: WishlistTheme.Metrics.margin),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -WishlistTheme.Metrics.margin),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { nil }

    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? .systemFill : .clear }
    }
}

enum FormKeyboardToolbar {
    /// Toolbar shown above the keyboard with a single "Done" button.
    ///
    /// Needed because a multiline `UITextView` has no return key to dismiss
    /// with — Return inserts a newline there. Returns a fresh instance per
    /// call: an accessory view can only live in one responder at a time.
    static func make(target: Any, action: Selector) -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .done, target: target, action: action)
        ]
        toolbar.tintColor = WishlistTheme.accent
        toolbar.sizeToFit()
        return toolbar
    }
}

enum FormButton {
    /// Prominent capsule button used as the primary action of a sheet.
    static func makeProminent(title: String, symbolName: String?) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = WishlistTheme.accent
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .large
        configuration.imagePadding = 8
        if let symbolName {
            configuration.image = UIImage(systemName: symbolName)
        }
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .preferredFont(forTextStyle: .headline)
            return outgoing
        }

        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: WishlistTheme.Metrics.buttonHeight).isActive = true
        return button
    }
}

/// Blurred bar pinned to the bottom of a sheet, holding the primary action.
final class BottomActionBar: UIView {
    init(button: UIButton) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)

        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = .separator
        addSubview(separator)

        addSubview(button)

        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),

            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

            button.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            button.leadingAnchor.constraint(equalTo: leadingAnchor, constant: WishlistTheme.Metrics.margin),
            button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -WishlistTheme.Metrics.margin),
            button.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) { nil }
}
