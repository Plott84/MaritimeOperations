import Foundation
import SwiftUI
import UIKit

/// Writes PDF / CSV to temporary URLs and presents Share / AirPrint.
@MainActor
enum ExportDocumentBuilder {
    struct Artifacts {
        var pdfURL: URL
        var csvURL: URL
    }

    /// Builds PDF (desk card via ImageRenderer) + CSV in the system temp directory.
    static func makeArtifacts(
        snapshot: ExportSnapshot,
        books: ExportBookSelection,
        filter: ExportDateFilter
    ) throws -> Artifacts {
        let stamp = ISO8601DateFormatter().string(from: .now)
            .replacingOccurrences(of: ":", with: "-")
        let base = "MaritimeOperations-Export-\(stamp)"
        let tmp = FileManager.default.temporaryDirectory

        let pdfURL = tmp.appendingPathComponent("\(base).pdf")
        let csvURL = tmp.appendingPathComponent("\(base).csv")

        let csv = makeCSV(snapshot: snapshot, books: books, filter: filter)
        try csv.write(to: csvURL, atomically: true, encoding: .utf8)

        try renderPDF(
            to: pdfURL,
            content: ExportDeskCardView(snapshot: snapshot, books: books, filter: filter)
        )

        return Artifacts(pdfURL: pdfURL, csvURL: csvURL)
    }

    static func makeCSV(
        snapshot: ExportSnapshot,
        books: ExportBookSelection,
        filter: ExportDateFilter
    ) -> String {
        var rows: [String] = []
        rows.append("book,count,hours,notes")
        for book in books.selectedBooks {
            let count = snapshot.count(for: book)
            let hours: String
            if book == .anchorHandling {
                hours = String(format: "%.1f", snapshot.anchorHours)
            } else if let h = snapshot.hours(for: book) {
                hours = String(format: "%.1f", h)
            } else {
                hours = "0.0"
            }
            let note: String
            switch book {
            case .dp: note = "DP book only; ROV/Crane excluded"
            case .anchorHandling: note = "count is rig moves"
            case .rov: note = "piloting hours"
            case .crane: note = "hours operated"
            }
            rows.append("\"\(book.title)\",\(count),\(hours),\"\(note)\"")
        }
        rows.append("")
        rows.append("period,\"\(periodCSV(filter))\"")
        rows.append("disclaimer,\"\(ExportDisclaimer.text)\"")
        rows.append("rule,\"\(ExportDisclaimer.previewFooter)\"")
        return rows.joined(separator: "\n") + "\n"
    }

    private static func periodCSV(_ filter: ExportDateFilter) -> String {
        if filter.isAllTime { return "All time" }
        let df = Date.FormatStyle(date: .abbreviated, time: .omitted)
        let fromText = filter.from.map { $0.formatted(df) } ?? ""
        let toText = filter.to.map { $0.formatted(df) } ?? ""
        return "\(fromText) – \(toText)"
    }

    private static func renderPDF(to url: URL, content: some View) throws {
        let pageWidth: CGFloat = 595  // A4 points
        let pageHeight: CGFloat = 842
        let renderer = ImageRenderer(
            content: content
                .frame(width: pageWidth, height: pageHeight)
                .environment(\.colorScheme, .light)
        )
        renderer.proposedSize = ProposedViewSize(width: pageWidth, height: pageHeight)
        renderer.scale = 2

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        var written = false
        renderer.render { size, renderInContext in
            var mediaBox = CGRect(origin: .zero, size: size)
            guard let pdf = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else { return }
            pdf.beginPDFPage(nil)
            renderInContext(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
            written = true
        }
        guard written, FileManager.default.fileExists(atPath: url.path) else {
            throw ExportDocumentError.pdfRenderFailed
        }
    }

    static func presentShare(pdfURL: URL, csvURL: URL, from presenter: UIViewController) {
        let items: [Any] = [pdfURL, csvURL]
        let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let pop = activity.popoverPresentationController {
            pop.sourceView = presenter.view
            pop.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.maxY - 40,
                width: 1,
                height: 1
            )
            pop.permittedArrowDirections = []
        }
        presenter.present(activity, animated: true)
    }

    static func presentPrint(pdfURL: URL, from presenter: UIViewController) {
        guard UIPrintInteractionController.isPrintingAvailable else { return }
        let printInfo = UIPrintInfo.printInfo()
        printInfo.outputType = .general
        printInfo.jobName = "Maritime Operations Export"
        let controller = UIPrintInteractionController.shared
        controller.printInfo = printInfo
        controller.printingItem = pdfURL
        // Phone: present(animated:). iPad share/print uses the activity sheet path for popovers.
        controller.present(animated: true)
    }

    /// Top-most presented view controller for Share / Print sheets.
    static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let root = base ?? keyRootViewController()
        if let nav = root as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = root?.presentedViewController {
            return topViewController(base: presented)
        }
        return root
    }

    private static func keyRootViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            if let key = scene.windows.first(where: \.isKeyWindow) {
                return key.rootViewController
            }
        }
        return scenes.flatMap(\.windows).first?.rootViewController
    }
}

enum ExportDocumentError: Error {
    case pdfRenderFailed
}
