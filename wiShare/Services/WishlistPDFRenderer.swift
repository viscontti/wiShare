import UIKit

/// Renders a wishlist into a shareable, paginated PDF: a header with the icon
/// and comment, then one card per item with photo, note and a clickable link.
enum WishlistPDFRenderer {
    private enum Layout {
        static let page = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4 at 72dpi
        static let margin: CGFloat = 48
        static let thumbnail: CGFloat = 72
        static let gutter: CGFloat = 16
        static let itemSpacing: CGFloat = 18
        static let footerReserve: CGFloat = 46

        static var contentWidth: CGFloat { page.width - margin * 2 }
        static var textWidth: CGFloat { contentWidth - thumbnail - gutter }
        static var textOriginX: CGFloat { margin + thumbnail + gutter }
    }

    /// PDF colours are baked in light appearance — a document has no traits.
    private enum Ink {
        private static let light = UITraitCollection(userInterfaceStyle: .light)

        static let accent = WishlistTheme.accent.resolvedColor(with: light)
        static let accentDeep = WishlistTheme.accentDeep.resolvedColor(with: light)
        static let accentSoft = WishlistTheme.accentSoft.resolvedColor(with: light)
        static let primary = UIColor.black
        static let secondary = UIColor(white: 0.42, alpha: 1)
        static let separator = UIColor(white: 0.86, alpha: 1)
    }

    private enum Font {
        static let title = UIFont.systemFont(ofSize: 26, weight: .bold)
        static let subtitle = UIFont.systemFont(ofSize: 12, weight: .semibold)
        static let body = UIFont.systemFont(ofSize: 12.5)
        static let itemTitle = UIFont.systemFont(ofSize: 15, weight: .semibold)
        static let itemBody = UIFont.systemFont(ofSize: 11.5)
        static let footer = UIFont.systemFont(ofSize: 9.5)
    }

    // MARK: - Entry point

    /// Resolves an item's photo file name to the full-size image.
    typealias PhotoProvider = (String) -> UIImage?

    private static let defaultPhotoProvider: PhotoProvider = { PhotoStorage.shared.image(named: $0) }

    /// Renders the wishlist and writes it to a temporary file ready for sharing.
    /// - Returns: the file URL of the written PDF.
    static func writePDF(
        for wishlist: Wishlist,
        photoProvider: @escaping PhotoProvider = defaultPhotoProvider
    ) throws -> URL {
        let data = makePDFData(for: wishlist, photoProvider: photoProvider)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName(for: wishlist))
        try data.write(to: url, options: .atomic)
        return url
    }

    static func makePDFData(
        for wishlist: Wishlist,
        photoProvider: @escaping PhotoProvider = defaultPhotoProvider
    ) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: wishlist.title,
            kCGPDFContextCreator as String: "wiShare"
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: Layout.page, format: format)
        return renderer.pdfData { context in
            var page = 1
            context.beginPage()

            var cursor = drawHeader(for: wishlist, context: context)

            for item in wishlist.items {
                let height = itemHeight(for: item)

                if cursor + height > Layout.page.height - Layout.footerReserve {
                    drawFooter(page: page, context: context)
                    context.beginPage()
                    page += 1
                    cursor = Layout.margin
                } else if cursor > Layout.margin {
                    drawSeparator(atY: cursor - Layout.itemSpacing / 2)
                }

                let photo = item.photoFileName.flatMap(photoProvider)
                draw(item: item, photo: photo, atY: cursor, context: context)
                cursor += height + Layout.itemSpacing
            }

            if wishlist.items.isEmpty {
                drawEmptyNotice(atY: cursor)
            }

            drawFooter(page: page, context: context)
        }
    }

    /// Small preview of an already-written PDF, used as the share-sheet thumbnail.
    static func thumbnail(ofPDFAt url: URL, size: CGSize) -> UIImage? {
        guard let document = CGPDFDocument(url as CFURL),
              let firstPage = document.page(at: 1)
        else { return nil }

        let pageRect = firstPage.getBoxRect(.mediaBox)
        let scale = min(size.width / pageRect.width, size.height / pageRect.height)
        let target = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

        return UIGraphicsImageRenderer(size: target).image { rendererContext in
            let cgContext = rendererContext.cgContext
            UIColor.white.setFill()
            cgContext.fill(CGRect(origin: .zero, size: target))

            cgContext.translateBy(x: 0, y: target.height)
            cgContext.scaleBy(x: scale, y: -scale)
            cgContext.drawPDFPage(firstPage)
        }
    }

    // MARK: - Header

    private static func drawHeader(for wishlist: Wishlist, context: UIGraphicsPDFRendererContext) -> CGFloat {
        let tileSize: CGFloat = 56
        let tileRect = CGRect(x: Layout.margin, y: Layout.margin, width: tileSize, height: tileSize)

        let tilePath = UIBezierPath(roundedRect: tileRect, cornerRadius: 14)
        Ink.accentSoft.setFill()
        tilePath.fill()

        let symbolName = UIImage(systemName: wishlist.symbolName) == nil
            ? WishlistTheme.defaultSymbol
            : wishlist.symbolName
        if let symbol = UIImage(
            systemName: symbolName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 26, weight: .medium)
        )?.withTintColor(Ink.accentDeep, renderingMode: .alwaysOriginal) {
            let origin = CGPoint(
                x: tileRect.midX - symbol.size.width / 2,
                y: tileRect.midY - symbol.size.height / 2
            )
            symbol.draw(at: origin)
        }

        let textX = tileRect.maxX + Layout.gutter
        let textWidth = Layout.page.width - Layout.margin - textX

        let title = NSAttributedString(
            string: wishlist.title,
            attributes: [.font: Font.title, .foregroundColor: Ink.primary]
        )
        let titleHeight = height(of: title, width: textWidth)
        title.draw(in: CGRect(x: textX, y: tileRect.minY + 2, width: textWidth, height: titleHeight))

        let subtitle = NSAttributedString(
            string: wishlist.itemCountText.uppercased(),
            attributes: [.font: Font.subtitle, .foregroundColor: Ink.accent, .kern: 0.6]
        )
        subtitle.draw(
            in: CGRect(x: textX, y: tileRect.minY + titleHeight + 8, width: textWidth, height: 18)
        )

        var cursor = max(tileRect.maxY, tileRect.minY + titleHeight + 28) + 18

        if !wishlist.comment.isEmpty {
            let comment = NSAttributedString(
                string: wishlist.comment,
                attributes: [.font: Font.body, .foregroundColor: Ink.secondary]
            )
            let commentHeight = height(of: comment, width: Layout.contentWidth)
            comment.draw(
                in: CGRect(x: Layout.margin, y: cursor, width: Layout.contentWidth, height: commentHeight)
            )
            cursor += commentHeight + 18
        }

        drawSeparator(atY: cursor)
        return cursor + Layout.itemSpacing
    }

    // MARK: - Items

    private static func itemHeight(for item: WishlistItem) -> CGFloat {
        var textHeight = height(of: attributedTitle(for: item), width: Layout.textWidth)

        if let comment = attributedComment(for: item) {
            textHeight += 5 + height(of: comment, width: Layout.textWidth)
        }
        if let link = attributedLink(for: item) {
            textHeight += 7 + height(of: link, width: Layout.textWidth)
        }

        return max(Layout.thumbnail, textHeight)
    }

    private static func draw(
        item: WishlistItem,
        photo: UIImage?,
        atY y: CGFloat,
        context: UIGraphicsPDFRendererContext
    ) {
        let thumbnailRect = CGRect(
            x: Layout.margin,
            y: y,
            width: Layout.thumbnail,
            height: Layout.thumbnail
        )
        drawThumbnail(photo, in: thumbnailRect, context: context)

        var cursor = y

        let title = attributedTitle(for: item)
        let titleHeight = height(of: title, width: Layout.textWidth)
        title.draw(in: CGRect(x: Layout.textOriginX, y: cursor, width: Layout.textWidth, height: titleHeight))
        cursor += titleHeight

        if let comment = attributedComment(for: item) {
            cursor += 5
            let commentHeight = height(of: comment, width: Layout.textWidth)
            comment.draw(
                in: CGRect(x: Layout.textOriginX, y: cursor, width: Layout.textWidth, height: commentHeight)
            )
            cursor += commentHeight
        }

        if let link = attributedLink(for: item), let url = item.productURL {
            cursor += 7
            let linkHeight = height(of: link, width: Layout.textWidth)
            let linkRect = CGRect(x: Layout.textOriginX, y: cursor, width: Layout.textWidth, height: linkHeight)
            link.draw(in: linkRect)
            // Makes the text a real, tappable annotation in the PDF.
            context.setURL(url, for: linkRect)
        }
    }

    private static func drawThumbnail(
        _ photo: UIImage?,
        in rect: CGRect,
        context: UIGraphicsPDFRendererContext
    ) {
        let cgContext = context.cgContext
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 12)

        guard let image = photo else {
            Ink.accentSoft.setFill()
            path.fill()

            if let placeholder = UIImage(
                systemName: "photo",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
            )?.withTintColor(Ink.accentDeep, renderingMode: .alwaysOriginal) {
                placeholder.draw(at: CGPoint(
                    x: rect.midX - placeholder.size.width / 2,
                    y: rect.midY - placeholder.size.height / 2
                ))
            }
            return
        }

        cgContext.saveGState()
        path.addClip()

        // Aspect fill inside the rounded frame.
        let scale = max(rect.width / image.size.width, rect.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        image.draw(in: CGRect(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2,
            width: size.width,
            height: size.height
        ))

        cgContext.restoreGState()
    }

    private static func attributedTitle(for item: WishlistItem) -> NSAttributedString {
        NSAttributedString(
            string: item.title,
            attributes: [.font: Font.itemTitle, .foregroundColor: Ink.primary]
        )
    }

    private static func attributedComment(for item: WishlistItem) -> NSAttributedString? {
        guard !item.comment.isEmpty else { return nil }
        return NSAttributedString(
            string: item.comment,
            attributes: [.font: Font.itemBody, .foregroundColor: Ink.secondary]
        )
    }

    private static func attributedLink(for item: WishlistItem) -> NSAttributedString? {
        guard let url = item.productURL else { return nil }
        return NSAttributedString(
            string: url.absoluteString,
            attributes: [
                .font: Font.itemBody,
                .foregroundColor: Ink.accent,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        )
    }

    // MARK: - Chrome

    private static func drawSeparator(atY y: CGFloat) {
        let line = UIBezierPath()
        line.move(to: CGPoint(x: Layout.margin, y: y))
        line.addLine(to: CGPoint(x: Layout.page.width - Layout.margin, y: y))
        line.lineWidth = 0.5
        Ink.separator.setStroke()
        line.stroke()
    }

    private static func drawEmptyNotice(atY y: CGFloat) {
        let notice = NSAttributedString(
            string: "This wishlist has no items yet.",
            attributes: [.font: Font.itemBody, .foregroundColor: Ink.secondary]
        )
        notice.draw(in: CGRect(x: Layout.margin, y: y, width: Layout.contentWidth, height: 20))
    }

    private static func drawFooter(page: Int, context: UIGraphicsPDFRendererContext) {
        let y = Layout.page.height - Layout.margin + 6

        let left = NSAttributedString(
            string: "Shared from wiShare · \(formattedToday())",
            attributes: [.font: Font.footer, .foregroundColor: Ink.secondary]
        )
        left.draw(in: CGRect(x: Layout.margin, y: y, width: Layout.contentWidth - 40, height: 14))

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        let right = NSAttributedString(
            string: "\(page)",
            attributes: [
                .font: Font.footer,
                .foregroundColor: Ink.secondary,
                .paragraphStyle: paragraph
            ]
        )
        right.draw(in: CGRect(x: Layout.margin, y: y, width: Layout.contentWidth, height: 14))
    }

    // MARK: - Helpers

    private static func height(of text: NSAttributedString, width: CGFloat) -> CGFloat {
        let bounds = text.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return ceil(bounds.height)
    }

    private static func formattedToday() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }

    /// Sanitised, human-readable file name — this is what shows up in Telegram.
    private static func fileName(for wishlist: Wishlist) -> String {
        let allowed = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "-_()"))

        let cleaned = wishlist.title.unicodeScalars
            .filter { allowed.contains($0) }
            .reduce(into: "") { $0.unicodeScalars.append($1) }
            .trimmingCharacters(in: .whitespaces)

        return (cleaned.isEmpty ? "Wishlist" : cleaned) + ".pdf"
    }
}
