import UIKit
import SafariServices

/// One priority group, plus the trailing section holding "Add Item".
///
/// `nonisolated` because the module builds with default main-actor isolation,
/// and a diffable data source needs its identifier types to be `Sendable`.
private nonisolated enum DetailSection: Hashable {
    case priority(ItemPriority)
    case add

    var priority: ItemPriority? {
        if case .priority(let priority) = self { return priority }
        return nil
    }
}

/// Rows are addressed by the item's id rather than by position, so an item
/// moving between groups reads as a move and gets animated as one.
private nonisolated enum DetailRow: Hashable {
    case item(UUID)
    case placeholder(ItemPriority)
    case addItem

    var itemID: UUID? {
        if case .item(let id) = self { return id }
        return nil
    }
}

/// Contents of one wishlist. Read-only browsing; "Edit" reopens the sheet.
final class WishlistDetailViewController: UIViewController {
    private let wishlistID: UUID
    private let store: WishlistStore
    private var storeObservation: ObservationToken?

    /// Folded groups. Deliberately not persisted: which headers are open is
    /// throwaway view state, not something the user owns.
    private var collapsedPriorities: Set<ItemPriority> = []

    private var renderedItems: [UUID: WishlistItem] = [:]

    /// Resolved on demand, so an edit made anywhere shows up here.
    private var wishlist: Wishlist? {
        store.wishlist(with: wishlistID)
    }

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = WishlistTheme.background
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = UITableView.automaticDimension
        tableView.estimatedSectionHeaderHeight = 40
        tableView.delegate = self
        tableView.register(WishlistItemCell.self, forCellReuseIdentifier: WishlistItemCell.reuseIdentifier)
        tableView.register(AddItemCell.self, forCellReuseIdentifier: AddItemCell.reuseIdentifier)
        tableView.register(EmptyPriorityCell.self, forCellReuseIdentifier: EmptyPriorityCell.reuseIdentifier)
        tableView.register(
            PrioritySectionHeaderView.self,
            forHeaderFooterViewReuseIdentifier: PrioritySectionHeaderView.reuseIdentifier
        )
        return tableView
    }()

    private lazy var dataSource = makeDataSource()

    private lazy var emptyStateView: EmptyStateView = {
        let view = EmptyStateView.init(
            symbolName: "tray",
            title: "No Items",
            message: "Add products with a photo, a note and a link.",
            actionTitle: "Add Item"
        )
        view.onAction { [weak self] in self?.addItem() }
        return view
    }()

    private lazy var headerView = WishlistHeaderView()

    private lazy var shareButton = UIBarButtonItem(
        barButtonSystemItem: .action,
        target: self,
        action: #selector(shareWishlist)
    )

    private lazy var addButton: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addItem))
        button.accessibilityLabel = "Add item"
        return button
    }()

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
        // Rightmost first: `+` lands where it sits on the list screen.
        navigationItem.rightBarButtonItems = [
            addButton,
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

        dataSource.apply(makeSnapshot(for: wishlist), animatingDifferences: true)
        view.setNeedsLayout()
    }

    // MARK: - Data source

    private func makeDataSource() -> UITableViewDiffableDataSource<DetailSection, DetailRow> {
        let source = UITableViewDiffableDataSource<DetailSection, DetailRow>(tableView: tableView) { [weak self] tableView, indexPath, row in
            switch row {
            case .item(let id):
                let cell = tableView.dequeueReusableCell(
                    withIdentifier: WishlistItemCell.reuseIdentifier,
                    for: indexPath
                )
                guard let cell = cell as? WishlistItemCell, let item = self?.item(with: id) else { return cell }
                cell.configure(
                    with: item,
                    photo: item.photoFileName.flatMap { PhotoStorage.shared.thumbnail(named: $0) }
                )
                return cell

            case .placeholder:
                return tableView.dequeueReusableCell(
                    withIdentifier: EmptyPriorityCell.reuseIdentifier,
                    for: indexPath
                )

            case .addItem:
                return tableView.dequeueReusableCell(
                    withIdentifier: AddItemCell.reuseIdentifier,
                    for: indexPath
                )
            }
        }
        source.defaultRowAnimation = .fade
        return source
    }

    private func makeSnapshot(for wishlist: Wishlist) -> NSDiffableDataSourceSnapshot<DetailSection, DetailRow> {
        var snapshot = NSDiffableDataSourceSnapshot<DetailSection, DetailRow>()

        // An untouched wishlist shows the big empty state instead; three empty
        // groups in a row would read as a broken screen.
        guard !wishlist.items.isEmpty else { return snapshot }

        for priority in ItemPriority.allCases {
            snapshot.appendSections([.priority(priority)])
            guard !collapsedPriorities.contains(priority) else { continue }

            let rows = wishlist.items(with: priority).map { DetailRow.item($0.id) }
            // All three groups stay on screen, so an unused one needs a row to
            // say so — a bare header reads as a rendering glitch.
            snapshot.appendItems(rows.isEmpty ? [.placeholder(priority)] : rows, toSection: .priority(priority))
        }

        snapshot.appendSections([.add])
        snapshot.appendItems([.addItem], toSection: .add)

        let onScreen = Set(dataSource.snapshot().itemIdentifiers)
        let changed = snapshot.itemIdentifiers.filter { row in
            guard let id = row.itemID, onScreen.contains(row) else { return false }
            return renderedItems[id] != item(with: id)
        }
        if !changed.isEmpty {
            snapshot.reconfigureItems(changed)
        }

        renderedItems = Dictionary(uniqueKeysWithValues: wishlist.items.map { ($0.id, $0) })
        return snapshot
    }

    private func item(with id: UUID) -> WishlistItem? {
        wishlist?.items.first { $0.id == id }
    }

    // MARK: - Priority

    private func toggleCollapse(_ priority: ItemPriority) {
        let willCollapse = !collapsedPriorities.contains(priority)
        if willCollapse {
            collapsedPriorities.insert(priority)
        } else {
            collapsedPriorities.remove(priority)
        }

        UISelectionFeedbackGenerator().selectionChanged()

        // Headers live outside the snapshot, so the chevron is turned by hand.
        if let index = dataSource.snapshot().indexOfSection(.priority(priority)),
           let header = tableView.headerView(forSection: index) as? PrioritySectionHeaderView {
            header.setCollapsed(willCollapse, animated: true)
        }

        render()
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

    /// Straight to the item form — no detour through the wishlist editor.
    @objc private func addItem() {
        guard wishlist != nil else { return }

        let itemEditor = WishlistItemEditorViewController(item: nil)
        itemEditor.delegate = self

        let navigationController = UINavigationController(rootViewController: itemEditor)
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

extension WishlistDetailViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch dataSource.itemIdentifier(for: indexPath) {
        case .addItem:
            addItem()
        case .item(let id):
            guard let url = item(with: id)?.productURL else { return }
            open(url)
        default:
            break
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let priority = dataSource.sectionIdentifier(for: section)?.priority,
              let header = tableView.dequeueReusableHeaderFooterView(
                withIdentifier: PrioritySectionHeaderView.reuseIdentifier
              ) as? PrioritySectionHeaderView
        else { return nil }

        header.configure(
            title: priority.sectionTitle,
            count: wishlist?.items(with: priority).count ?? 0,
            isCollapsed: collapsedPriorities.contains(priority)
        ) { [weak self] in
            self?.toggleCollapse(priority)
        }
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // The "Add Item" section carries no header, and no gap where one was.
        dataSource.sectionIdentifier(for: section)?.priority == nil
            ? .leastNormalMagnitude
            : UITableView.automaticDimension
    }

    /// Long press to move an item between priorities. Also the accessible path:
    /// picking from a menu asks far less of the hand than any gesture would.
    func tableView(
        _ tableView: UITableView,
        contextMenuConfigurationForRowAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let id = dataSource.itemIdentifier(for: indexPath)?.itemID,
              let item = item(with: id)
        else { return nil }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let actions = ItemPriority.allCases.map { priority in
                UIAction(
                    title: priority.title,
                    image: UIImage(systemName: priority.symbolName),
                    state: item.priority == priority ? .on : .off
                ) { _ in
                    guard let self else { return }
                    self.store.setPriority(priority, forItemID: id, inWishlistWithID: self.wishlistID)
                }
            }

            return UIMenu(children: [
                UIMenu(title: "Priority", image: UIImage(systemName: "flag"), children: actions)
            ])
        }
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

// MARK: - Item editor delegate

extension WishlistDetailViewController: WishlistItemEditorDelegate {
    func wishlistItemEditor(
        _ editor: WishlistItemEditorViewController,
        didFinishWith item: WishlistItem,
        editingID: UUID?
    ) {
        // Re-read the wishlist here: it may have changed while the sheet was up.
        guard var wishlist else {
            editor.dismiss(animated: true)
            return
        }

        if let editingID, let index = wishlist.items.firstIndex(where: { $0.id == editingID }) {
            wishlist.items[index] = item
        } else {
            wishlist.items.append(item)
        }

        store.update(wishlist)
        editor.dismiss(animated: true)
    }
}

/// Tappable header of a priority group: a chevron that folds it, the group's
/// name and how many items are inside — the count is what keeps a folded group
/// readable.
final class PrioritySectionHeaderView: UITableViewHeaderFooterView {
    static let reuseIdentifier = "PrioritySectionHeaderView"

    private let chevronView = UIImageView(image: UIImage(systemName: "chevron.down"))
    private let titleLabel = UILabel()
    private let countLabel = UILabel()
    private let button = UIButton(type: .system)
    private var onToggle: (() -> Void)?

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        chevronView.translatesAutoresizingMaskIntoConstraints = false
        chevronView.tintColor = .secondaryLabel
        chevronView.contentMode = .scaleAspectFit
        chevronView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            textStyle: .caption1,
            scale: .small
        )

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .preferredFont(forTextStyle: .footnote)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .secondaryLabel

        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.font = .preferredFont(forTextStyle: .footnote)
        countLabel.adjustsFontForContentSizeCategory = true
        countLabel.textColor = .tertiaryLabel

        button.translatesAutoresizingMaskIntoConstraints = false
        button.addAction(UIAction { [weak self] _ in self?.onToggle?() }, for: .touchUpInside)

        contentView.addSubview(chevronView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(countLabel)
        contentView.addSubview(button)

        NSLayoutConstraint.activate([
            chevronView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            chevronView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: 12),

            titleLabel.leadingAnchor.constraint(equalTo: chevronView.trailingAnchor, constant: 6),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -7),

            countLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 6),
            countLabel.firstBaselineAnchor.constraint(equalTo: titleLabel.firstBaselineAnchor),
            countLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: contentView.layoutMarginsGuide.trailingAnchor
            ),

            button.topAnchor.constraint(equalTo: contentView.topAnchor),
            button.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { nil }

    func configure(title: String, count: Int, isCollapsed: Bool, onToggle: @escaping () -> Void) {
        titleLabel.text = title
        countLabel.text = "\(count)"
        self.onToggle = onToggle
        setCollapsed(isCollapsed, animated: false)

        button.accessibilityLabel = title
        button.accessibilityValue = count == 1 ? "1 item" : "\(count) items"
        button.accessibilityHint = isCollapsed ? "Double tap to expand" : "Double tap to collapse"
    }

    /// Animated only when the user did the folding — a header being recycled
    /// while scrolling must not spin its chevron.
    func setCollapsed(_ isCollapsed: Bool, animated: Bool) {
        let transform = isCollapsed ? CGAffineTransform(rotationAngle: -.pi / 2) : .identity
        guard animated else {
            chevronView.transform = transform
            return
        }
        UIView.animate(withDuration: 0.25) { self.chevronView.transform = transform }
    }
}

/// Stand-in row for a priority nobody has used yet, so an always-visible group
/// never shows up as a header with nothing under it.
final class EmptyPriorityCell: UITableViewCell {
    static let reuseIdentifier = "EmptyPriorityCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = WishlistTheme.surface
        selectionStyle = .none

        var content = UIListContentConfiguration.cell()
        content.text = "No items"
        content.textProperties.color = .tertiaryLabel
        content.textProperties.font = .preferredFont(forTextStyle: .subheadline)
        content.textProperties.adjustsFontForContentSizeCategory = true
        content.image = UIImage(systemName: "tray")
        content.imageProperties.tintColor = .tertiaryLabel
        content.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .subheadline)
        contentConfiguration = content
    }

    required init?(coder: NSCoder) { nil }
}

/// Trailing row of the items section: tinted "Add Item" call to action, the way
/// Contacts closes a section with "add field".
final class AddItemCell: UITableViewCell {
    static let reuseIdentifier = "AddItemCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = WishlistTheme.surface

        let selectedBackground = UIView()
        selectedBackground.backgroundColor = WishlistTheme.accentSoft
        selectedBackgroundView = selectedBackground

        var content = UIListContentConfiguration.cell()
        content.text = "Add Item"
        content.textProperties.color = WishlistTheme.accent
        content.textProperties.font = .preferredFont(forTextStyle: .body)
        content.textProperties.adjustsFontForContentSizeCategory = true
        content.image = UIImage(systemName: "plus.circle.fill")
        content.imageProperties.tintColor = WishlistTheme.accent
        content.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .body)
        contentConfiguration = content

        accessibilityTraits.insert(.button)
    }

    required init?(coder: NSCoder) { nil }
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
