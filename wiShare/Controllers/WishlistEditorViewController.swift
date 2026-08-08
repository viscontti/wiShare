import UIKit

/// Bottom sheet for creating or editing a wishlist: icon, name, note and the
/// list of items. "Done" hands the assembled wishlist back to the delegate.
final class WishlistEditorViewController: UIViewController {
    weak var delegate: WishlistEditorDelegate?

    private let editingID: UUID?
    private var items: [WishlistItem]
    private var symbolName: String

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let titleRow = FormFieldRow(placeholder: "Wishlist name", icon: "textformat")
    private let noteRow = FormNoteRow(placeholder: "Add a comment (optional)")
    private lazy var symbolPicker = SymbolPickerView(selected: symbolName)
    private let itemsSection = FormSectionView(rows: [])
    private lazy var doneButton = FormButton.makeProminent(title: "Done", symbolName: "checkmark")
    private lazy var bottomBar = BottomActionBar(button: doneButton)

    init(wishlist: Wishlist?) {
        editingID = wishlist?.id
        items = wishlist?.items ?? []
        symbolName = wishlist?.symbolName ?? WishlistTheme.defaultSymbol
        super.init(nibName: nil, bundle: nil)

        title = wishlist == nil ? "New Wishlist" : "Edit Wishlist"
        titleRow.textField.text = wishlist?.title
        noteRow.text = wishlist?.comment ?? ""
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = WishlistTheme.background
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancel)
        )

        setupLayout()
        reloadItemRows()
        observeKeyboard()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if editingID == nil {
            titleRow.textField.becomeFirstResponder()
        }
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

        symbolPicker.onSelect = { [weak self] symbol in
            self?.symbolName = symbol
        }

        titleRow.textField.returnKeyType = .next
        titleRow.textField.delegate = self

        titleRow.textField.inputAccessoryView = makeKeyboardToolbar()
        noteRow.textView.inputAccessoryView = makeKeyboardToolbar()
        installTapToDismissKeyboard()

        let addItemRow = FormActionRow(title: "Add Item", symbolName: "plus.circle.fill")
        addItemRow.addTarget(self, action: #selector(addItem), for: .touchUpInside)

        contentStack.addArrangedSubview(FormHeaderLabel.wrapped("Icon"))
        contentStack.addArrangedSubview(FormSectionView(rows: [symbolPicker]))
        contentStack.addArrangedSubview(FormHeaderLabel.wrapped("Details"))
        contentStack.addArrangedSubview(FormSectionView(rows: [titleRow, noteRow]))
        contentStack.addArrangedSubview(FormHeaderLabel.wrapped("Items"))
        contentStack.addArrangedSubview(itemsSection)
        contentStack.addArrangedSubview(FormSectionView(rows: [addItemRow]))
        contentStack.setCustomSpacing(12, after: itemsSection)
        contentStack.addArrangedSubview(
            FormFooterLabel.wrapped("Each item can carry a photo, a note and a link to the product.")
        )

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

        doneButton.addTarget(self, action: #selector(finish), for: .touchUpInside)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let inset = bottomBar.bounds.height
        guard scrollView.contentInset.bottom < inset else { return }
        scrollView.contentInset.bottom = inset
        scrollView.verticalScrollIndicatorInsets.bottom = inset
    }

    private func reloadItemRows() {
        guard !items.isEmpty else {
            let placeholder = FormActionRow(title: "No items yet", symbolName: "tray")
            placeholder.isUserInteractionEnabled = false
            placeholder.alpha = 0.55
            itemsSection.setRows([placeholder])
            return
        }

        let rows: [UIView] = items.map { item in
            let photo = item.photoFileName.flatMap { PhotoStorage.shared.thumbnail(named: $0) }
            let row = WishlistItemSummaryView(item: item, photo: photo)
            row.addAction(for: .touchUpInside) { [weak self] in
                self?.editItem(id: item.id)
            }
            row.onRemove = { [weak self] in
                self?.removeItem(id: item.id)
            }
            return row
        }
        itemsSection.setRows(rows)
    }

    private func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
        UIView.animate(withDuration: 0.2) { self.reloadItemRows() }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func editItem(id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        presentItemEditor(item: item)
    }

    private func presentItemEditor(item: WishlistItem?) {
        view.endEditing(true)

        let itemEditor = WishlistItemEditorViewController(item: item)
        itemEditor.delegate = self

        let navigationController = UINavigationController(rootViewController: itemEditor)
        navigationController.presentAsSheet(from: self)
    }

    // MARK: - Actions

    @objc private func addItem() {
        presentItemEditor(item: nil)
    }

    @objc private func finish() {
        view.endEditing(true)

        let trimmedTitle = titleRow.textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedTitle.isEmpty else {
            titleRow.flagAsInvalid()
            titleRow.textField.becomeFirstResponder()
            return
        }

        let wishlist = Wishlist(
            id: editingID ?? UUID(),
            title: trimmedTitle,
            comment: noteRow.text.trimmingCharacters(in: .whitespacesAndNewlines),
            symbolName: symbolName,
            items: items
        )
        delegate?.wishlistEditor(self, didFinishWith: wishlist, editingID: editingID)
    }

    @objc private func cancel() {
        dismiss(animated: true)
    }

    // MARK: - Keyboard

    private func makeKeyboardToolbar() -> UIToolbar {
        FormKeyboardToolbar.make(target: self, action: #selector(dismissKeyboard))
    }

    /// Tapping anywhere outside a field closes the keyboard, the way system
    /// forms behave. `cancelsTouchesInView` stays false so rows still fire.
    private func installTapToDismissKeyboard() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(tap)
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

// MARK: - Text field

extension WishlistEditorViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        noteRow.textView.becomeFirstResponder()
        return true
    }
}

// MARK: - Item editor delegate

extension WishlistEditorViewController: WishlistItemEditorDelegate {
    func wishlistItemEditor(
        _ editor: WishlistItemEditorViewController,
        didFinishWith item: WishlistItem,
        editingID: UUID?
    ) {
        if let editingID, let index = items.firstIndex(where: { $0.id == editingID }) {
            items[index] = item
        } else {
            items.append(item)
        }

        reloadItemRows()
        editor.dismiss(animated: true)
    }
}
