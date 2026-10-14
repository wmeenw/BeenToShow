import SwiftUI
import UIKit
import ImageIO

/// Собирает дневник концертов в многостраничный PDF в тёмной теме приложения.
nonisolated enum PDFExporter {
    private static let pageSize = CGRect(x: 0, y: 0, width: 595, height: 842)
    private static let margin: CGFloat = 40

    private static let bg = UIColor(red: 0x0B/255, green: 0x0B/255, blue: 0x0F/255, alpha: 1)
    private static let card = UIColor(red: 0x15/255, green: 0x15/255, blue: 0x1B/255, alpha: 1)
    private static let pink = UIColor(red: 0xFF/255, green: 0x4F/255, blue: 0xB8/255, alpha: 1)
    private static let violet = UIColor(red: 0x8B/255, green: 0x5C/255, blue: 0xFF/255, alpha: 1)
    private static let lime = UIColor(red: 0xD4/255, green: 0xFF/255, blue: 0x3A/255, alpha: 1)

    private static func unbounded(_ size: CGFloat) -> UIFont {
        UIFont(name: "Unbounded-Regular_Bold", size: size)
            ?? UIFont(name: "Unbounded-Regular", size: size)
            ?? .systemFont(ofSize: size, weight: .bold)
    }
    private static func onest(_ size: CGFloat, bold: Bool = false) -> UIFont {
        UIFont(name: bold ? "Onest-SemiBold" : "Onest-Regular", size: size)
            ?? .systemFont(ofSize: size, weight: bold ? .semibold : .regular)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM yyyy"
        return f
    }()

    /// Возвращает URL временного PDF или nil, если нечего экспортировать.
    static func export(concerts: [Concert]) -> URL? {
        BTSFonts.register()
        let past = concerts.filter { $0.isPast }.sorted { $0.date > $1.date }
        guard !past.isEmpty else { return nil }

        let url = FileManager.default.temporaryDirectory.appending(path: "BeenToShow-дневник.pdf")
        try? FileManager.default.removeItem(at: url)

        let meta = [kCGPDFContextTitle as String: "BeenToShow — дневник концертов"]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = meta
        let renderer = UIGraphicsPDFRenderer(bounds: pageSize, format: format)

        var y: CGFloat = 0
        let contentWidth = pageSize.width - margin * 2

        func newPage(_ ctx: UIGraphicsPDFRendererContext) {
            ctx.beginPage()
            bg.setFill()
            ctx.fill(pageSize)
            y = margin
        }

        func textHeight(_ s: String, font: UIFont, width: CGFloat) -> CGFloat {
            ceil((s as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font], context: nil).height)
        }

        @discardableResult
        func draw(_ s: String, font: UIFont, color: UIColor, x: CGFloat = margin, width: CGFloat = contentWidth) -> CGFloat {
            let h = textHeight(s, font: font, width: width)
            (s as NSString).draw(in: CGRect(x: x, y: y, width: width, height: h),
                                 withAttributes: [.font: font, .foregroundColor: color])
            y += h
            return h
        }

        func ratingText(_ r: Double) -> String {
            let v = (r * 10).rounded() / 10
            return "★ " + (v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v).replacingOccurrences(of: ".", with: ","))
        }

        try? renderer.writePDF(to: url) { ctx in
            // Титул и сводка
            newPage(ctx)
            y = 150
            draw("BeenToShow", font: unbounded(34), color: pink)
            y += 6
            draw("Дневник концертов", font: onest(18), color: UIColor.white.withAlphaComponent(0.7))
            y += 40

            let cities = Set(past.map { $0.city.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
            let rated = past.compactMap { $0.rating }
            let avg = rated.isEmpty ? nil : rated.reduce(0, +) / Double(rated.count)

            let stats: [(String, String)] = [
                ("Концертов", "\(past.count)"),
                ("Городов", "\(cities.count)"),
                ("Средняя оценка", avg.map { ratingText($0) } ?? "—")
            ]
            let boxW = (contentWidth - 24) / 3
            for (i, s) in stats.enumerated() {
                let x = margin + CGFloat(i) * (boxW + 12)
                let rect = CGRect(x: x, y: y, width: boxW, height: 90)
                card.setFill()
                UIBezierPath(roundedRect: rect, cornerRadius: 16).fill()
                let saved = y
                y = saved + 16
                draw(s.1, font: unbounded(22), color: lime, x: x + 12, width: boxW - 24)
                y += 6
                draw(s.0, font: onest(12), color: UIColor.white.withAlphaComponent(0.6), x: x + 12, width: boxW - 24)
                y = saved
            }
            y += 90 + 40
            if let first = past.last, let last = past.first {
                draw("\(dateFormatter.string(from: first.date)) — \(dateFormatter.string(from: last.date))",
                     font: onest(14), color: UIColor.white.withAlphaComponent(0.5))
            }

            // Концерты
            let photoGap: CGFloat = 8
            let photoSize = (contentWidth - photoGap * 2) / 3
            let tagsFont = onest(12)

            func ensure(_ h: CGFloat) {
                if y + h > pageSize.height - margin { newPage(ctx) }
            }

            newPage(ctx)
            for c in past {
                autoreleasepool {
                    let artistFont = unbounded(18)
                    var sub = "\(c.city) · \(dateFormatter.string(from: c.date))"
                    if let r = c.rating { sub += " · \(ratingText(r))" }
                    let subFont = onest(13, bold: true)
                    let tagsText = c.tags.isEmpty ? nil : c.tags.map { "#\($0)" }.joined(separator: "  ")
                    let commentFont = onest(13)
                    let maxBlock = pageSize.height - margin * 2
                    let commentChunks: [String]
                    if let comment = c.comment, !comment.isEmpty {
                        commentChunks = splitText(comment, font: commentFont, width: contentWidth, maxHeight: maxBlock)
                    } else {
                        commentChunks = []
                    }
                    // Заголовок не отрываем от первого блока: одна проверка места на всю шапку.
                    var headH = textHeight(c.artist, font: artistFont, width: contentWidth) + 6
                        + textHeight(sub, font: subFont, width: contentWidth) + 8
                    if let t = tagsText { headH += textHeight(t, font: tagsFont, width: contentWidth) + 8 }
                    if let first = commentChunks.first {
                        headH += min(textHeight(first, font: commentFont, width: contentWidth), 120) + 8
                    }
                    ensure(min(headH, maxBlock))
                    draw(c.artist, font: artistFont, color: .white)
                    y += 6
                    draw(sub, font: subFont, color: pink)
                    y += 8
                    if let t = tagsText {
                        draw(t, font: tagsFont, color: violet)
                        y += 8
                    }
                    for (i, chunk) in commentChunks.enumerated() {
                        let h = textHeight(chunk, font: commentFont, width: contentWidth)
                        if i > 0 { ensure(h + 8) }
                        else if y + h > pageSize.height - margin { newPage(ctx) }
                        draw(chunk, font: commentFont, color: UIColor.white.withAlphaComponent(0.85))
                    }
                    if !commentChunks.isEmpty { y += 8 }

                    var col = 0
                    for name in c.photoNames {
                        autoreleasepool {
                            let fileURL = URL.documentsDirectory.appending(path: name)
                            guard let img = downscaled(fileURL, maxPixel: 600) else { return }
                            if col == 0 { ensure(photoSize + photoGap) }
                            let rect = CGRect(x: margin + CGFloat(col) * (photoSize + photoGap), y: y,
                                              width: photoSize, height: photoSize)
                            card.setFill()
                            UIBezierPath(roundedRect: rect, cornerRadius: 10).fill()
                            ctx.cgContext.saveGState()
                            UIBezierPath(roundedRect: rect, cornerRadius: 10).addClip()
                            let s = max(rect.width / img.size.width, rect.height / img.size.height)
                            let w = img.size.width * s, h = img.size.height * s
                            img.draw(in: CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h))
                            ctx.cgContext.restoreGState()
                            col += 1
                            if col == 3 { col = 0; y += photoSize + photoGap }
                        }
                    }
                    if col != 0 { y += photoSize + photoGap }

                    y += 10
                    if y < pageSize.height - margin {
                        UIColor.white.withAlphaComponent(0.08).setFill()
                        ctx.fill(CGRect(x: margin, y: y, width: contentWidth, height: 1))
                    }
                    y += 20
                }
            }
        }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    /// Режет длинный текст на куски, каждый из которых помещается в maxHeight: по абзацам, а абзац — по словам.
    private static func splitText(_ text: String, font: UIFont, width: CGFloat, maxHeight: CGFloat) -> [String] {
        func height(_ s: String) -> CGFloat {
            ceil((s as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font], context: nil).height)
        }
        var result: [String] = []
        var current = ""
        func flush() {
            if !current.isEmpty { result.append(current); current = "" }
        }
        // Абзацы собираем в куски не выше одной страницы (но не больше ~1/3 страницы за раз,
        // чтобы текст плавно перетекал между страницами).
        let limit = min(maxHeight, 240)
        for para in text.components(separatedBy: "\n") {
            if para.isEmpty { continue }
            if height(para) <= limit {
                let candidate = current.isEmpty ? para : current + "\n" + para
                if height(candidate) <= limit { current = candidate } else { flush(); current = para }
            } else {
                flush()
                var line = ""
                for word in para.split(separator: " ", omittingEmptySubsequences: true) {
                    let candidate = line.isEmpty ? String(word) : line + " " + word
                    if height(candidate) <= limit || line.isEmpty { line = candidate }
                    else { result.append(line); line = String(word) }
                }
                if !line.isEmpty { current = line }
            }
        }
        flush()
        return result
    }

    private static func downscaled(_ url: URL, maxPixel: Int) -> UIImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }
}

struct ShareablePDF: Identifiable {
    let id = UUID()
    let url: URL
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
