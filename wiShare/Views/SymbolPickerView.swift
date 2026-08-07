import UIKit

/// Horizontal strip of SF Symbols used to give a wishlist an icon.
final class SymbolPickerView: UIView {
    var onSelect: ((String) -> Void)?

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private var buttons: [String: UIButton] = [:]

    private(set) var selectedSymbol: String {
        didSet { updateSelection() }
    }

    init(symbols: [String] = WishlistTheme.symbolCatalog, selected: String = WishlistTheme.defaultSymbol) {
        selectedSymbol = symbols.contains(selected) ? selected : (symbols.first ?? WishlistTheme.defaultSymbol)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInset = UIEdgeInsets(top: 0, left: WishlistTheme.Metrics.margin, bottom: 0, right: WishlistTheme.Metrics.margin)
        addSubview(scrollView)

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 10
        scrollView.addSubview(stack)

        for symbol in symbols {
            let button = makeButton(for: symbol)
            buttons[symbol] = button
            stack.addArrangedSubview(button)
        }

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 72),

            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -14)
        ])

        updateSelection()
    }

    required init?(coder: NSCoder) { nil }

    private func makeButton(for symbol: String) -> UIButton {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(
            UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .medium)),
            for: .normal
        )
        button.layer.cornerRadius = WishlistTheme.Metrics.tileCorner
        button.layer.cornerCurve = .continuous
        button.accessibilityLabel = symbol.replacingOccurrences(of: ".", with: " ")
        button.addTarget(self, action: #selector(selectSymbol(_:)), for: .touchUpInside)
        button.widthAnchor.constraint(equalToConstant: WishlistTheme.Metrics.tile).isActive = true
        button.heightAnchor.constraint(equalToConstant: WishlistTheme.Metrics.tile).isActive = true
        return button
    }

    @objc private func selectSymbol(_ sender: UIButton) {
        guard let symbol = buttons.first(where: { $0.value === sender })?.key else { return }
        selectedSymbol = symbol
        UISelectionFeedbackGenerator().selectionChanged()
        onSelect?(symbol)
    }

    private func updateSelection() {
        for (symbol, button) in buttons {
            let isSelected = symbol == selectedSymbol
            button.backgroundColor = isSelected ? WishlistTheme.accent : WishlistTheme.accentSoft
            button.tintColor = isSelected ? .white : WishlistTheme.accentDeep
            button.accessibilityTraits = isSelected ? [.button, .selected] : [.button]
        }
    }
}
