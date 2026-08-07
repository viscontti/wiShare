import UIKit
import PhotosUI

/// Bottom sheet for one wishlist item: photo, name, note and product link.
final class WishlistItemEditorViewController: UIViewController {
    weak var delegate: WishlistItemEditorDelegate?

    private let editingID: UUID?
    private var selectedImage: UIImage?

    private let linkMetadataService = LinkMetadataService()
    /// Once the user picks or removes a photo by hand, link previews stop
    /// overwriting it — they can still pull one in explicitly from the menu.
    private var photoChosenByUser: Bool
    private var lastPreviewedURL: URL?

    private let scrollView = UIScrollView()
    private let photoRow = PhotoPickerRow()
    private let titleRow = FormFieldRow(placeholder: "Product name", icon: "tag")
    private let noteRow = FormNoteRow(placeholder: "Add a comment (optional)")
    private let linkRow = FormFieldRow(placeholder: "https://…", icon: "link")
    private lazy var saveButton = FormButton.makeProminent(
        title: editingID == nil ? "Add Item" : "Save",
        symbolName: editingID == nil ? "plus" : "checkmark"
    )
    private lazy var bottomBar = BottomActionBar(button: saveButton)

    init(item: WishlistItem?) {
        editingID = item?.id
        selectedImage = item?.image
        photoChosenByUser = item?.image != nil
        lastPreviewedURL = item?.productURL
        super.init(nibName: nil, bundle: nil)

        title = item == nil ? "New Item" : "Edit Item"
        titleRow.textField.text = item?.title
        noteRow.text = item?.comment ?? ""
        linkRow.textField.text = item?.productURL?.absoluteString
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
        photoRow.setImage(selectedImage)
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

        let contentStack = UIStackView()
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 0
        scrollView.addSubview(contentStack)

        photoRow.addAction(for: .touchUpInside) { [weak self] in self?.presentPhotoOptions() }

        linkRow.textField.keyboardType = .URL
        linkRow.textField.autocapitalizationType = .none
        linkRow.textField.autocorrectionType = .no
        linkRow.textField.textContentType = .URL

        titleRow.textField.returnKeyType = .next
        titleRow.textField.delegate = self

        // The link is the last field, so its return key finishes editing.
        linkRow.textField.returnKeyType = .done
        linkRow.textField.delegate = self

        titleRow.textField.inputAccessoryView = makeKeyboardToolbar()
        noteRow.textView.inputAccessoryView = makeKeyboardToolbar()
        linkRow.textField.inputAccessoryView = makeKeyboardToolbar()
        installTapToDismissKeyboard()

        contentStack.addArrangedSubview(FormHeaderLabel.wrapped("Photo"))
        contentStack.addArrangedSubview(FormSectionView(rows: [photoRow]))
        contentStack.addArrangedSubview(FormHeaderLabel.wrapped("Details"))
        contentStack.addArrangedSubview(FormSectionView(rows: [titleRow, noteRow]))
        contentStack.addArrangedSubview(FormHeaderLabel.wrapped("Link"))
        contentStack.addArrangedSubview(FormSectionView(rows: [linkRow]))
        contentStack.addArrangedSubview(
            FormFooterLabel.wrapped("Tapping the item in a wishlist opens this link. If the page has a preview image, it is used as the photo automatically.")
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

        saveButton.addTarget(self, action: #selector(saveItem), for: .touchUpInside)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let inset = bottomBar.bounds.height
        guard scrollView.contentInset.bottom < inset else { return }
        scrollView.contentInset.bottom = inset
        scrollView.verticalScrollIndicatorInsets.bottom = inset
    }

    // MARK: - Photo

    private func presentPhotoOptions() {
        view.endEditing(true)

        let linkURL = currentLinkURL()
        guard selectedImage != nil || linkURL != nil else {
            presentPhotoPicker()
            return
        }

        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: selectedImage == nil ? "Choose Photo" : "Change Photo", style: .default) { [weak self] _ in
            self?.presentPhotoPicker()
        })

        if let linkURL {
            alert.addAction(UIAlertAction(title: "Use Photo from Link", style: .default) { [weak self] _ in
                self?.loadPreview(from: linkURL, force: true)
            })
        }

        if selectedImage != nil {
            alert.addAction(UIAlertAction(title: "Remove Photo", style: .destructive) { [weak self] _ in
                self?.selectedImage = nil
                self?.photoChosenByUser = true
                self?.photoRow.setImage(nil)
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.popoverPresentationController?.sourceView = photoRow
        alert.popoverPresentationController?.sourceRect = photoRow.bounds
        present(alert, animated: true)
    }

    // MARK: - Link preview

    private func currentLinkURL() -> URL? {
        let raw = linkRow.textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return nil }
        return Self.normalizedURL(from: raw)
    }

    /// Fetches the page's preview image. Runs automatically once per URL after
    /// the link field loses focus; `force` re-runs it on explicit request.
    private func loadPreview(from url: URL, force: Bool) {
        if !force {
            guard !photoChosenByUser, url != lastPreviewedURL else { return }
        }
        lastPreviewedURL = url

        photoRow.setLoading(true)
        linkMetadataService.fetchPreview(for: url) { [weak self] preview in
            guard let self else { return }
            self.photoRow.setLoading(false)

            guard let image = preview?.image else {
                if force { self.presentPreviewUnavailable() }
                return
            }

            self.selectedImage = image
            self.photoRow.setImage(image)
            if force { self.photoChosenByUser = true }

            // Only fills a name the user hasn't written themselves.
            let currentTitle = self.titleRow.textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if currentTitle.isEmpty, let suggested = preview?.title, !suggested.isEmpty {
                self.titleRow.textField.text = suggested
            }
        }
    }

    private func presentPreviewUnavailable() {
        let alert = UIAlertController(
            title: "No Photo Found",
            message: "This page doesn’t provide a preview image. You can add one from your library instead.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func presentPhotoPicker() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    // MARK: - Actions

    @objc private func saveItem() {
        view.endEditing(true)

        let trimmedTitle = titleRow.textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedTitle.isEmpty else {
            titleRow.flagAsInvalid()
            titleRow.textField.becomeFirstResponder()
            return
        }

        let rawLink = linkRow.textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var url: URL?
        if !rawLink.isEmpty {
            url = Self.normalizedURL(from: rawLink)
            guard url != nil else {
                linkRow.flagAsInvalid()
                linkRow.textField.becomeFirstResponder()
                return
            }
        }

        let item = WishlistItem(
            id: editingID ?? UUID(),
            image: selectedImage,
            title: trimmedTitle,
            comment: noteRow.text.trimmingCharacters(in: .whitespacesAndNewlines),
            productURL: url
        )
        delegate?.wishlistItemEditor(self, didFinishWith: item, editingID: editingID)
    }

    /// Accepts "shop.com/item" as well as a full URL, and rejects plain text.
    private static func normalizedURL(from raw: String) -> URL? {
        let candidate = raw.contains("://") ? raw : "https://\(raw)"
        guard let url = URL(string: candidate),
              let host = url.host, host.contains("."),
              url.scheme == "http" || url.scheme == "https"
        else { return nil }
        return url
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

extension WishlistItemEditorViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === titleRow.textField {
            noteRow.textView.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        guard textField === linkRow.textField, let url = currentLinkURL() else { return }
        loadPreview(from: url, force: false)
    }
}

// MARK: - Photo picker

extension WishlistItemEditorViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            DispatchQueue.main.async {
                self?.selectedImage = image
                self?.photoChosenByUser = true
                self?.photoRow.setImage(image)
            }
        }
    }
}

/// Row with a square preview tile and a "Add / Change Photo" label.
final class PhotoPickerRow: UIControl {
    private let tileView = UIImageView()
    private let titleLabel = UILabel()
    private let chevronView = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let spinner = UIActivityIndicatorView(style: .medium)

    private var currentImage: UIImage?
    private var isLoading = false

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
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = WishlistTheme.accent

        chevronView.translatesAutoresizingMaskIntoConstraints = false
        chevronView.tintColor = .tertiaryLabel
        chevronView.contentMode = .scaleAspectFit
        chevronView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .footnote)

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = WishlistTheme.accentDeep
        spinner.hidesWhenStopped = true

        addSubview(tileView)
        addSubview(titleLabel)
        addSubview(chevronView)
        addSubview(spinner)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 88),

            spinner.centerXAnchor.constraint(equalTo: tileView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: tileView.centerYAnchor),

            tileView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: WishlistTheme.Metrics.margin),
            tileView.centerYAnchor.constraint(equalTo: centerYAnchor),
            tileView.widthAnchor.constraint(equalToConstant: 64),
            tileView.heightAnchor.constraint(equalToConstant: 64),

            titleLabel.leadingAnchor.constraint(equalTo: tileView.trailingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevronView.leadingAnchor, constant: -8),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            chevronView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -WishlistTheme.Metrics.margin),
            chevronView.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: 10)
        ])
    }

    required init?(coder: NSCoder) { nil }

    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? .systemFill : .clear }
    }

    func setImage(_ image: UIImage?) {
        currentImage = image
        applyState()
    }

    func setLoading(_ loading: Bool) {
        isLoading = loading
        applyState()
    }

    private func applyState() {
        guard !isLoading else {
            spinner.startAnimating()
            tileView.image = nil
            titleLabel.text = "Loading preview…"
            titleLabel.textColor = .secondaryLabel
            chevronView.isHidden = true
            isEnabled = false
            accessibilityLabel = titleLabel.text
            return
        }

        spinner.stopAnimating()
        chevronView.isHidden = false
        isEnabled = true
        titleLabel.textColor = WishlistTheme.accent

        if let currentImage {
            tileView.image = currentImage
            tileView.contentMode = .scaleAspectFill
            titleLabel.text = "Change Photo"
        } else {
            tileView.image = UIImage(
                systemName: "photo.on.rectangle.angled",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
            )
            tileView.contentMode = .center
            titleLabel.text = "Add Photo"
        }
        accessibilityLabel = titleLabel.text
    }
}
