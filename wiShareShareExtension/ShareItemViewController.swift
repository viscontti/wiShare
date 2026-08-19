import UIKit
import UniformTypeIdentifiers

/// Capture form shown when a page is shared from Safari: pulls the product's
/// title and photo from the page, lets the name and note be edited, and asks
/// which wishlist it belongs to.
final class ShareItemViewController: UIViewController {
    private let store = WishlistStore.shared
    private let photoStorage = PhotoStorage.shared
    private let linkMetadataService = LinkMetadataService()

    private var sharedURL: URL?
    private var previewImage: UIImage?

    /// `nil` means the "New Wishlist" option is selected.
    private var selectedWishlistID: UUID?
    private var pickerRows: [SharePickerRow] = []

    private lazy var wishlists = store.wishlists

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let photoRow = SharePhotoRow()
    private let titleRow = FormFieldRow(placeholder: "Product name", icon: "tag")
    private let noteRow = FormNoteRow(placeholder: "Add a comment (optional)")
    private let linkRow = ShareLinkRow()
    private let newListRow = FormFieldRow(placeholder: "New wishlist name", icon: "plus.circle")
    /// Anything caught from Safari starts as medium; the app is where it gets
    /// nudged up or down later.
    private let priorityRow = FormSegmentedRow(
        titles: ItemPriority.allCases.map(\.title),
        selectedIndex: ItemPriority.medium.rawValue
    )
    private let pickerSection = FormSectionView(rows: [])
    private lazy var addButton = FormButton.makeProminent(title: "Add to Wishlist", symbolName: "plus")
    private lazy var bottomBar = BottomActionBar(button: addButton)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Add to wiShare"
        view.backgroundColor = WishlistTheme.background

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancel)
        )

        // Default to the first existing wishlist, or to creating one.
        selectedWishlistID = wishlists.first?.id

        setupLayout()
        reloadPickerRows()
        observeKeyboard()
        loadSharedItem()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let inset = bottomBar.bounds.height
        guard scrollView.contentInset.bottom < inset else { return }
        scrollView.contentInset.bottom = inset
        scrollView.verticalScrollIndicatorInsets.bottom = inset
    }

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        view.addSubview(bottomBar)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 0
        scrollView.addSubview(contentStack)

        titleRow.textField.inputAccessoryView = makeKeyboardToolbar()
        noteRow.textView.inputAccessoryView = makeKeyboardToolbar()
        newListRow.textField.inputAccessoryView = makeKeyboardToolbar()
        newListRow.isHidden = true

        contentStack.addArrangedSubview(FormHeaderLabel.wrapped("Item"))
        contentStack.addArrangedSubview(FormSectionView(rows: [photoRow, titleRow, noteRow]))
        contentStack.addArrangedSubview(FormHeaderLabel.wrapped("Link"))
        contentStack.addArrangedSubview(FormSectionView(rows: [linkRow]))
        contentStack.addArrangedSubview(FormHeaderLabel.wrapped("Add to"))
        contentStack.addArrangedSubview(pickerSection)
        contentStack.addArrangedSubview(newListRow)
        contentStack.setCustomSpacing(12, after: pickerSection)
        contentStack.addArrangedSubview(FormHeaderLabel.wrapped("Priority"))
        contentStack.addArrangedSubview(FormSectionView(rows: [priorityRow]))

        newListRow.backgroundColor = WishlistTheme.surface
        newListRow.layer.cornerRadius = WishlistTheme.Metrics.corner
        newListRow.layer.cornerCurve = .continuous
        newListRow.clipsToBounds = true

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentStack.leadingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.leadingAnchor,
                constant: WishlistTheme.Metrics.margin
            ),
            contentStack.trailingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.trailingAnchor,
                constant: -WishlistTheme.Metrics.margin
            )
        ])

        addButton.addTarget(self, action: #selector(addItem), for: .touchUpInside)
    }

    // MARK: - Wishlist picker

    private func reloadPickerRows() {
        var rows: [SharePickerRow] = wishlists.map { wishlist in
            let row = SharePickerRow(
                title: wishlist.title,
                subtitle: wishlist.itemCountText,
                symbolName: wishlist.symbolName
            )
            row.addAction(for: .touchUpInside) { [weak self] in
                self?.selectWishlist(id: wishlist.id)
            }
            return row
        }

        let newRow = SharePickerRow(title: "New Wishlist", subtitle: nil, symbolName: "plus.circle.fill")
        newRow.addAction(for: .touchUpInside) { [weak self] in
            self?.selectWishlist(id: nil)
        }
        rows.append(newRow)

        pickerRows = rows
        pickerSection.setRows(rows)
        updatePickerSelection()
    }

    private func selectWishlist(id: UUID?) {
        selectedWishlistID = id
        UISelectionFeedbackGenerator().selectionChanged()
        updatePickerSelection()

        if id == nil {
            newListRow.textField.becomeFirstResponder()
        } else {
            view.endEditing(true)
        }
    }

    private func updatePickerSelection() {
        for (index, row) in pickerRows.enumerated() {
            let rowID: UUID? = index < wishlists.count ? wishlists[index].id : nil
            row.isPicked = rowID == selectedWishlistID
        }

        let isCreatingNew = selectedWishlistID == nil
        guard newListRow.isHidden == isCreatingNew else { return }
        UIView.animate(withDuration: 0.2) {
            self.newListRow.isHidden = !isCreatingNew
            self.newListRow.alpha = isCreatingNew ? 1 : 0
        }
    }

    // MARK: - Incoming item

    private func loadSharedItem() {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .compactMap(\.attachments)
            .flatMap { $0 }

        let urlType = UTType.url.identifier
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(urlType) }) else {
            photoRow.setLoading(false)
            return
        }

        photoRow.setLoading(true)
        provider.loadItem(forTypeIdentifier: urlType, options: nil) { [weak self] value, _ in
            let url = value as? URL
            DispatchQueue.main.async {
                self?.apply(url: url)
            }
        }
    }

    private func apply(url: URL?) {
        guard let url else {
            photoRow.setLoading(false)
            return
        }

        sharedURL = url
        linkRow.setURL(url)

        linkMetadataService.fetchPreview(for: url) { [weak self] preview in
            guard let self else { return }
            self.photoRow.setLoading(false)

            if let image = preview?.image {
                self.previewImage = image
                self.photoRow.setImage(image)
            }

            let currentTitle = self.titleRow.textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if currentTitle.isEmpty, let suggested = preview?.title, !suggested.isEmpty {
                self.titleRow.textField.text = suggested
            }
        }
    }

    // MARK: - Actions

    @objc private func addItem() {
        view.endEditing(true)

        guard SharedContainer.isUsingAppGroup else {
            presentFailure(
                title: "Sharing Unavailable",
                message: "wiShare can’t reach its shared storage. Open the app once, then try again."
            )
            return
        }

        let trimmedTitle = titleRow.textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedTitle.isEmpty else {
            titleRow.flagAsInvalid()
            titleRow.textField.becomeFirstResponder()
            return
        }

        var newWishlistTitle: String?
        if selectedWishlistID == nil {
            let name = newListRow.textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty else {
                newListRow.flagAsInvalid()
                newListRow.textField.becomeFirstResponder()
                return
            }
            newWishlistTitle = name
        }

        var photoFileName: String?
        if let previewImage {
            // A failed photo must not cost the user the item itself.
            photoFileName = try? photoStorage.save(previewImage)
        }

        let item = WishlistItem(
            photoFileName: photoFileName,
            title: trimmedTitle,
            comment: noteRow.text.trimmingCharacters(in: .whitespacesAndNewlines),
            productURL: sharedURL,
            priority: ItemPriority(rawValue: priorityRow.segmentedControl.selectedSegmentIndex) ?? .medium
        )
        let entry = ShareInboxEntry(
            wishlistID: selectedWishlistID,
            newWishlistTitle: newWishlistTitle,
            item: item
        )

        do {
            try ShareInbox.write(entry)
        } catch {
            presentFailure(
                title: "Couldn’t Save",
                message: "There may not be enough free space on your device."
            )
            return
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        extensionContext?.completeRequest(returningItems: nil)
    }

    @objc private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: "wiShare.share", code: NSUserCancelledError))
    }

    private func presentFailure(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Keyboard

    private func makeKeyboardToolbar() -> UIToolbar {
        FormKeyboardToolbar.make(target: self, action: #selector(dismissKeyboard))
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let overlap = max(0, view.bounds.maxY - view.convert(frame, from: nil).minY)
        scrollView.contentInset.bottom = max(overlap, bottomBar.bounds.height)
        scrollView.verticalScrollIndicatorInsets.bottom = scrollView.contentInset.bottom
    }

    @objc private func keyboardWillHide() {
        scrollView.contentInset.bottom = bottomBar.bounds.height
        scrollView.verticalScrollIndicatorInsets.bottom = bottomBar.bounds.height
    }
}

// MARK: - Rows

/// Photo pulled from the page, with a spinner while it is being fetched.
final class SharePhotoRow: UIView {
    private let tileView = UIImageView()
    private let titleLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        tileView.translatesAutoresizingMaskIntoConstraints = false
        tileView.backgroundColor = WishlistTheme.accentSoft
        tileView.tintColor = WishlistTheme.accentDeep
        tileView.clipsToBounds = true
        tileView.layer.cornerRadius = WishlistTheme.Metrics.tileCorner
        tileView.layer.cornerCurve = .continuous

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .preferredFont(forTextStyle: .subheadline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .secondaryLabel
        titleLabel.numberOfLines = 0

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = WishlistTheme.accentDeep
        spinner.hidesWhenStopped = true

        addSubview(tileView)
        addSubview(titleLabel)
        addSubview(spinner)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 88),

            tileView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: WishlistTheme.Metrics.margin),
            tileView.centerYAnchor.constraint(equalTo: centerYAnchor),
            tileView.widthAnchor.constraint(equalToConstant: 64),
            tileView.heightAnchor.constraint(equalToConstant: 64),

            spinner.centerXAnchor.constraint(equalTo: tileView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: tileView.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: tileView.trailingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -WishlistTheme.Metrics.margin),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        setImage(nil)
    }

    required init?(coder: NSCoder) { nil }

    func setImage(_ image: UIImage?) {
        spinner.stopAnimating()

        if let image {
            tileView.image = image
            tileView.contentMode = .scaleAspectFill
            titleLabel.text = "Photo from the page"
        } else {
            tileView.image = UIImage(
                systemName: "photo",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
            )
            tileView.contentMode = .center
            titleLabel.text = "No photo on this page"
        }
    }

    func setLoading(_ isLoading: Bool) {
        guard isLoading else { return }
        spinner.startAnimating()
        tileView.image = nil
        titleLabel.text = "Loading preview…"
    }
}

/// Read-only display of the shared address.
final class ShareLinkRow: UIView {
    private let label = UILabel()

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(systemName: "link"))
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = WishlistTheme.accent
        iconView.contentMode = .scaleAspectFit

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.lineBreakMode = .byTruncatingMiddle
        label.text = "No link"

        addSubview(iconView)
        addSubview(label)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: WishlistTheme.Metrics.rowHeight),

            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: WishlistTheme.Metrics.margin),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -WishlistTheme.Metrics.margin),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { nil }

    func setURL(_ url: URL) {
        label.text = url.host?.replacingOccurrences(of: "www.", with: "") ?? url.absoluteString
        label.textColor = WishlistTheme.accent
    }
}

/// Wishlist choice, with a checkmark for the picked one.
final class SharePickerRow: UIControl {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let checkView = UIImageView(image: UIImage(systemName: "checkmark"))

    var isPicked = false {
        didSet { checkView.isHidden = !isPicked }
    }

    init(title: String, subtitle: String?, symbolName: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = UIImage(systemName: symbolName) ?? UIImage(systemName: WishlistTheme.defaultSymbol)
        iconView.tintColor = WishlistTheme.accent
        iconView.contentMode = .scaleAspectFit

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.adjustsFontForContentSizeCategory = true

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = subtitle
        subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.isHidden = subtitle == nil

        checkView.translatesAutoresizingMaskIntoConstraints = false
        checkView.tintColor = WishlistTheme.accent
        checkView.contentMode = .scaleAspectFit
        checkView.isHidden = true

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.isUserInteractionEnabled = false

        addSubview(iconView)
        addSubview(textStack)
        addSubview(checkView)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 52),

            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: WishlistTheme.Metrics.margin),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),

            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: checkView.leadingAnchor, constant: -12),
            textStack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            textStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            checkView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -WishlistTheme.Metrics.margin),
            checkView.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkView.widthAnchor.constraint(equalToConstant: 18)
        ])
    }

    required init?(coder: NSCoder) { nil }

    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? .systemFill : .clear }
    }
}
