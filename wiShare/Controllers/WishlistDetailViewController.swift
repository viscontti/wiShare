import UIKit
import SafariServices

/// Contents of one wishlist. Read-only browsing; "Edit" reopens the sheet.
final class WishlistDetailViewController: UIViewController {
    private let wishlistID: UUID
    private let store: WishlistStore
    private var storeObservation: ObservationToken?

    /// Resolved on demand, so an edit made anywhere shows up here.
    private var wishlist: Wishlist? {
        store.wishlist(with: wishlistID)
    }

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = WishlistTheme.background
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(WishlistItemCell.self, forCellReuseIdentifier: WishlistItemCell.reuseIdentifier)
        return tableView
    }()

    private lazy var emptyStateView: EmptyStateView = {
        let view = EmptyStateView.init(
            symbolName: "tray",
            title: "No Items",
            message: "Add products with a photo, a note and a link.",
            actionTitle: "Add Item"
        )
        view.onAction { [weak self] in self?.editWishlist() }
        return view
    }()

    private lazy var headerView = WishlistHeaderView()

    private lazy var shareButton = UIBarButtonItem(
        barButtonSystemItem: .action,
        target: self,
        action: #selector(shareWishlist)
    )

    init(wishlistID: UUID, store: WishlistStore = .shared) {
        self.wishlistID = wishlistID
        self.store = store
        super.init(nibName: nil, bundle: nil)
        title = store.wishlist(with: wishlistID)?.title
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = WishlistTheme.background
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(editWishlist)),
            shareButton
        ]

        view.addSubview(tableView)
        view.addSubview(emptyStateView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateView.topAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        tableView.tableHeaderView = headerView
        render()

        storeObservation = store.observe { [weak self] in
            self?.render()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        sizeHeaderToFit()
    }

    private func sizeHeaderToFit() {
        let width = tableView.bounds.width
        guard width > 0 else { return }

        let target = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
        let height = headerView.systemLayoutSizeFitting(
            target,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height

        guard abs(headerView.frame.height - height) > 0.5 else { return }
        headerView.frame.size = CGSize(width: width, height: height)
        tableView.tableHeaderView = headerView
    }

    private func render() {
        // Deleted from the list screen while open — nothing left to show.
        guard let wishlist else {
            navigationController?.popViewController(animated: true)
            return
        }

        title = wishlist.title
        headerView.configure(with: wishlist)
        emptyStateView.isHidden = !wishlist.items.isEmpty
        tableView.reloadData()
        view.setNeedsLayout()
    }

    @objc private func shareWishlist() {
        guard let wishlist else { return }
        WishlistShareService.share(wishlist, from: self, anchor: .barButton(shareButton))
    }

    @objc private func editWishlist() {
        guard let wishlist else { return }

        let editor = WishlistEditorViewController(wishlist: wishlist)
        editor.delegate = self

        let navigationController = UINavigationController(rootViewController: editor)
        navigationController.presentAsSheet(from: self)
    }

    private func open(_ url: URL) {
        guard ["http", "https"].contains(url.scheme ?? "") else {
            UIApplication.shared.open(url)
            return
        }

        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false

        let safari = SFSafariViewController(url: url, configuration: configuration)
        safari.preferredControlTintColor = WishlistTheme.accent
        present(safari, animated: true)
    }
}

// MARK: - Table view

extension WishlistDetailViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        wishlist?.items.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: WishlistItemCell.reuseIdentifier, for: indexPath) as? WishlistItemCell,
              let item = wishlist?.items[indexPath.row]
        else {
            return UITableViewCell()
        }

        cell.configure(with: item, photo: item.photoFileName.flatMap { PhotoStorage.shared.thumbnail(named: $0) })
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let url = wishlist?.items[indexPath.row].productURL else { return }
        open(url)
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        (wishlist?.items.isEmpty ?? true) ? nil : "Items"
    }
}

// MARK: - Editor delegate

extension WishlistDetailViewController: WishlistEditorDelegate {
    func wishlistEditor(_ editor: WishlistEditorViewController, didFinishWith wishlist: Wishlist, editingID: UUID?) {
        // The store notifies back, which is what re-renders this screen.
        store.update(wishlist)
        dismiss(animated: true)
    }
}

/// Table header: large tinted icon, comment and an item-count chip.
final class WishlistHeaderView: UIView {
    private let iconContainer = UIView()
    private let iconView = UIImageView()
    private let commentLabel = UILabel()
    private let countLabel = PaddedLabel()

    init() {
        super.init(frame: .zero)

        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.backgroundColor = WishlistTheme.accentSoft
        iconContainer.layer.cornerRadius = 18
        iconContainer.layer.cornerCurve = .continuous

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = WishlistTheme.accentDeep
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 30, weight: .medium)
        iconContainer.addSubview(iconView)

        commentLabel.translatesAutoresizingMaskIntoConstraints = false
        commentLabel.font = .preferredFont(forTextStyle: .subheadline)
        commentLabel.adjustsFontForContentSizeCategory = true
        commentLabel.textColor = .secondaryLabel
        commentLabel.numberOfLines = 0

        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.font = .preferredFont(forTextStyle: .caption1)
        countLabel.adjustsFontForContentSizeCategory = true
        countLabel.textColor = WishlistTheme.accentDeep
        countLabel.backgroundColor = WishlistTheme.accentSoft
        countLabel.textAlignment = .center
        countLabel.insets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        countLabel.layer.cornerRadius = 10
        countLabel.layer.cornerCurve = .continuous
        countLabel.clipsToBounds = true

        let textStack = UIStackView(arrangedSubviews: [countLabel, commentLabel])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 8

        addSubview(iconContainer)
        addSubview(textStack)

        NSLayoutConstraint.activate([
            iconContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            iconContainer.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            iconContainer.widthAnchor.constraint(equalToConstant: 68),
            iconContainer.heightAnchor.constraint(equalToConstant: 68),
            iconContainer.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -16),

            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 16),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            textStack.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            textStack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 12),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -16)
        ])
    }

    required init?(coder: NSCoder) { nil }

    func configure(with wishlist: Wishlist) {
        iconView.image = UIImage(systemName: wishlist.symbolName) ?? UIImage(systemName: WishlistTheme.defaultSymbol)
        countLabel.text = wishlist.itemCountText
        commentLabel.text = wishlist.comment
        commentLabel.isHidden = wishlist.comment.isEmpty
    }
}
