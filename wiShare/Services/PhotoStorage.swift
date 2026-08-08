import UIKit

enum PhotoStorageError: Error {
    case encodingFailed
}

/// Stores item photos as files in `Documents/Photos`, keeping the models free
/// of image data so they stay `Codable` and cheap to persist.
///
/// Every photo is written twice: a downscaled full version used for PDF export
/// and a small thumbnail used by table cells. Reading a 200 px JPEG is fast
/// enough to stay on the main thread while scrolling, which is what lets the
/// cells avoid asynchronous loading and cell-reuse bookkeeping entirely.
///
/// Safe to use from any queue: `NSCache` is thread-safe and each call touches
/// its own files.
final class PhotoStorage {
    static let shared = PhotoStorage()

    private enum Limits {
        static let fullDimension: CGFloat = 1600
        static let thumbnailDimension: CGFloat = 200
        static let quality: CGFloat = 0.85
    }

    private let directory: URL
    private let fileManager = FileManager.default
    private let cache = NSCache<NSString, UIImage>()

    init(directory: URL? = nil) {
        self.directory = directory ?? Self.defaultDirectory()
        try? fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
        cache.countLimit = 120
    }

    private static func defaultDirectory() -> URL {
        // Shared, so the share extension writes photos the app can read.
        SharedContainer.directory(named: "Photos")
    }

    // MARK: - Writing

    /// Writes the image to disk and returns the file name to store in the model.
    @discardableResult
    func save(_ image: UIImage) throws -> String {
        let name = UUID().uuidString + ".jpg"

        let full = downscaled(image, maxDimension: Limits.fullDimension)
        guard let fullData = full.jpegData(compressionQuality: Limits.quality) else {
            throw PhotoStorageError.encodingFailed
        }
        try fullData.write(to: url(for: name), options: .atomic)
        cache.setObject(full, forKey: name as NSString)

        // A missing thumbnail only costs a slower first read, so it must not
        // fail the whole save.
        let thumbnailName = Self.thumbnailName(for: name)
        let thumbnail = downscaled(image, maxDimension: Limits.thumbnailDimension)
        if let thumbnailData = thumbnail.jpegData(compressionQuality: Limits.quality) {
            try? thumbnailData.write(to: url(for: thumbnailName), options: .atomic)
            cache.setObject(thumbnail, forKey: thumbnailName as NSString)
        }

        return name
    }

    // MARK: - Reading

    /// Full-size photo, for PDF export. Prefer `thumbnail(named:)` in cells.
    func image(named name: String) -> UIImage? {
        loadImage(fileName: name)
    }

    /// Small preview for list rows; falls back to the full image if the
    /// thumbnail is missing.
    func thumbnail(named name: String) -> UIImage? {
        loadImage(fileName: Self.thumbnailName(for: name)) ?? loadImage(fileName: name)
    }

    private func loadImage(fileName: String) -> UIImage? {
        if let cached = cache.object(forKey: fileName as NSString) {
            return cached
        }

        guard let data = try? Data(contentsOf: url(for: fileName)),
              let image = UIImage(data: data)
        else { return nil }

        cache.setObject(image, forKey: fileName as NSString)
        return image
    }

    // MARK: - Deleting

    func delete(named name: String) {
        for fileName in [name, Self.thumbnailName(for: name)] {
            try? fileManager.removeItem(at: url(for: fileName))
            cache.removeObject(forKey: fileName as NSString)
        }
    }

    /// Removes files no wishlist references any more.
    ///
    /// Needed because a photo is written to disk the moment it is picked, while
    /// the wishlist that references it is only committed when the editor is
    /// dismissed with Done — cancelling in between leaves the file behind.
    func deleteUnreferenced(keeping referenced: Set<String>) {
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return }

        let live = referenced.union(referenced.map(Self.thumbnailName(for:)))

        for file in files where !live.contains(file.lastPathComponent) {
            try? fileManager.removeItem(at: file)
            cache.removeObject(forKey: file.lastPathComponent as NSString)
        }
    }

    // MARK: - Helpers

    private func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    private static func thumbnailName(for name: String) -> String {
        let base = (name as NSString).deletingPathExtension
        return "\(base)_thumb.jpg"
    }

    /// Scales down to fit `maxDimension`, never up.
    private func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > maxDimension, longestSide > 0 else { return image }

        let scale = maxDimension / longestSide
        let size = CGSize(
            width: (image.size.width * scale).rounded(),
            height: (image.size.height * scale).rounded()
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
