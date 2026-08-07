import UIKit

/// Main screen: every wishlist as an inset-grouped row.
/// Create from the `+` bar button, edit or delete from a trailing swipe or a
/// long-press context menu.
final class WishlistListViewController: UIViewController {
    private var wishlists: [Wishlist] = []

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = WishlistTheme.background
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 84
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(WishlistCell.self, forCellReuseIdentifier: WishlistCell.reuseIdentifier)
        return tableView
    }()

    private lazy var emptyStateView: EmptyStateView = {
        let view = EmptyStateView(
            symbolName: "gift",
            title: "No Wishlists",
            message: "Create a wishlist to collect gift ideas, links and notes in one place.",
            actionTitle: "New Wishlist"
        )
        view.onAction { [weak self] in self?.showCreateWishlist() }
        view.isHidden = true
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "wiShare"
        view.backgroundColor = WishlistTheme.background

        navigationItem.largeTitleDisplayMode = .always
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(showCreateWishlist)
        )
        navigationItem.rightBarButtonItem?.accessibilityLabel = "New wishlist"

        setupLayout()
        updateEmptyState()
    }

    private func setupLayout() {
        view.addSubview(tableView)
        view.addSubview(emptyStateView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    // MARK: - Actions

    @objc private func showCreateWishlist() {
        presentWishlistEditor(wishlist: nil)
    }

    private func presentWishlistEditor(wishlist: Wishlist?) {
        let editor = WishlistEditorViewController(wishlist: wishlist)
        editor.delegate = self

        let navigationController = UINavigationController(rootViewController: editor)
        navigationController.presentAsSheet(from: self)
    }

    private func shareWishlist(at indexPath: IndexPath) {
        guard indexPath.row < wishlists.count else { return }
        WishlistShareService.share(
            wishlists[indexPath.row],
            from: self,
            anchor: .view(tableView, tableView.rectForRow(at: indexPath))
        )
    }

    private func confirmDelete(at indexPath: IndexPath, completion: @escaping (Bool) -> Void) {
        let wishlist = wishlists[indexPath.row]
        let alert = UIAlertController(
            title: "Delete “\(wishlist.title)”?",
            message: wishlist.items.isEmpty ? nil : "\(wishlist.itemCountText) will be removed as well.",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteWishlist(at: indexPath)
            completion(true)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completion(false) })
        alert.popoverPresentationController?.sourceView = tableView
        alert.popoverPresentationController?.sourceRect = tableView.rectForRow(at: indexPath)
        present(alert, animated: true)
    }

    private func deleteWishlist(at indexPath: IndexPath) {
        wishlists.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
        updateEmptyState()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func updateEmptyState() {
        emptyStateView.isHidden = !wishlists.isEmpty
        tableView.isHidden = wishlists.isEmpty
    }
}

// MARK: - Table view

extension WishlistListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        wishlists.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: WishlistCell.reuseIdentifier, for: indexPath) as? WishlistCell else {
            return UITableViewCell()
        }
        cell.configure(with: wishlists[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let detail = WishlistDetailViewController(wishlist: wishlists[indexPath.row])
        detail.onChange = { [weak self] updated in
            guard let self, let index = self.wishlists.firstIndex(where: { $0.id == updated.id }) else { return }
            self.wishlists[index] = updated
            self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
        }
        navigationController?.pushViewController(detail, animated: true)
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            self?.confirmDelete(at: indexPath, completion: completion)
        }
        deleteAction.image = UIImage(systemName: "trash")

        let editAction = UIContextualAction(style: .normal, title: "Edit") { [weak self] _, _, completion in
            guard let self else { return completion(false) }
            self.presentWishlistEditor(wishlist: self.wishlists[indexPath.row])
            completion(true)
        }
        editAction.image = UIImage(systemName: "pencil")
        editAction.backgroundColor = WishlistTheme.accent

        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, editAction])
        // A full swipe must not delete — the row only reveals the actions.
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }

    func tableView(
        _ tableView: UITableView,
        leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let shareAction = UIContextualAction(style: .normal, title: "Share") { [weak self] _, _, completion in
            self?.shareWishlist(at: indexPath)
            completion(true)
        }
        shareAction.image = UIImage(systemName: "square.and.arrow.up")
        shareAction.backgroundColor = WishlistTheme.accentDeep

        let configuration = UISwipeActionsConfiguration(actions: [shareAction])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }

    func tableView(
        _ tableView: UITableView,
        contextMenuConfigurationForRowAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            guard let self else { return nil }

            let edit = UIAction(title: "Edit", image: UIImage(systemName: "pencil")) { _ in
                self.presentWishlistEditor(wishlist: self.wishlists[indexPath.row])
            }
            let share = UIAction(title: "Share as PDF", image: UIImage(systemName: "square.and.arrow.up")) { _ in
                self.shareWishlist(at: indexPath)
            }
            let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                self.confirmDelete(at: indexPath) { _ in }
            }
            return UIMenu(children: [edit, share, delete])
        }
    }
}

// MARK: - Editor delegate

extension WishlistListViewController: WishlistEditorDelegate {
    func wishlistEditor(_ editor: WishlistEditorViewController, didFinishWith wishlist: Wishlist, editingID: UUID?) {
        if let editingID, let index = wishlists.firstIndex(where: { $0.id == editingID }) {
            wishlists[index] = wishlist
        } else {
            wishlists.insert(wishlist, at: 0)
        }

        tableView.reloadData()
        updateEmptyState()
        dismiss(animated: true)
    }
}

// MARK: - Sheet helper

extension UINavigationController {
    /// Presents as a bottom sheet with the standard medium/large detents.
    func presentAsSheet(from presenter: UIViewController, startLarge: Bool = true) {
        navigationBar.prefersLargeTitles = false
        modalPresentationStyle = .pageSheet

        if let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.selectedDetentIdentifier = startLarge ? .large : .medium
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            sheet.largestUndimmedDetentIdentifier = nil
        }

        presenter.present(self, animated: true)
    }
}
