import SwiftUI

/// Light desk-log card rendered to PDF via ImageRenderer. Not shown in the app chrome.
struct ExportDeskCardView: View {
    let snapshot: ExportSnapshot
    let books: ExportBookSelection
    let filter: ExportDateFilter

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Maritime Operations — personal log aid")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(red: 0.051, green: 0.086, blue: 0.114))
                .padding(.top, 8)

            Text("Personal DPO sea-time aid. Not a certification artifact. Not an NI letter.")
                .font(.system(size: 11).italic())
                .foregroundStyle(Color(red: 0.29, green: 0.33, blue: 0.38))
                .padding(.top, 4)
                .padding(.bottom, 10)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color(red: 0.051, green: 0.086, blue: 0.114))
                        .frame(height: 1.5)
                }

            HStack(alignment: .top, spacing: 24) {
                metaBlock(label: "Period", value: periodText)
            }
            .padding(.top, 16)
            .padding(.bottom, 18)

            if books.hasAnyBook && !snapshot.isEmpty(for: books) {
                tableHeader
                ForEach(books.selectedBooks, id: \.self) { book in
                    tableRow(book)
                }
                dividerHeavy
                if books.dp {
                    HStack {
                        Text("DP hours (DP book only)")
                            .font(.system(size: 13, weight: .bold))
                        Spacer()
                        Text(ExportSnapshot.hoursText(snapshot.dpHours))
                            .font(.system(size: 13, weight: .bold).monospacedDigit())
                    }
                    .padding(.top, 10)
                }
            } else {
                Text(ExportDisclaimer.emptyPreview)
                    .font(.system(size: 13).italic())
                    .foregroundStyle(Color(red: 0.42, green: 0.46, blue: 0.50))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
            }

            Spacer(minLength: 16)

            VStack(alignment: .leading, spacing: 4) {
                Text(ExportDisclaimer.text)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(red: 0.29, green: 0.33, blue: 0.38))
                Text(ExportDisclaimer.previewFooter)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(red: 0.051, green: 0.086, blue: 0.114))
            }
            .padding(.top, 16)
            .overlay(alignment: .top) {
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(Color(red: 0.60, green: 0.64, blue: 0.67))
                    .frame(height: 1)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 0.957, green: 0.945, blue: 0.918))
    }

    private var periodText: String {
        if filter.isAllTime { return "All time" }
        let df = Date.FormatStyle(date: .abbreviated, time: .omitted)
        let fromText = filter.from.map { $0.formatted(df) } ?? "—"
        let toText = filter.to.map { $0.formatted(df) } ?? "—"
        return "\(fromText) – \(toText)"
    }

    private func metaBlock(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Color(red: 0.42, green: 0.46, blue: 0.50))
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(Color(red: 0.10, green: 0.12, blue: 0.14))
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color(red: 0.60, green: 0.64, blue: 0.67))
                        .frame(height: 1)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tableHeader: some View {
        HStack {
            Text("BOOK")
            Spacer()
            Text("COUNT")
                .frame(width: 70, alignment: .trailing)
            Text("HOURS")
                .frame(width: 70, alignment: .trailing)
        }
        .font(.system(size: 10, weight: .bold))
        .tracking(0.7)
        .foregroundStyle(Color(red: 0.29, green: 0.33, blue: 0.38))
        .padding(.bottom, 6)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(red: 0.051, green: 0.086, blue: 0.114))
                .frame(height: 1.5)
        }
    }

    private func tableRow(_ book: LogBook) -> some View {
        HStack {
            Text(book.title)
                .font(.system(size: 13))
            Spacer()
            Text(countLabel(book))
                .font(.system(size: 13).monospacedDigit())
                .frame(width: 70, alignment: .trailing)
            Text(hoursLabel(book))
                .font(.system(size: 13).monospacedDigit())
                .frame(width: 70, alignment: .trailing)
        }
        .foregroundStyle(Color(red: 0.10, green: 0.12, blue: 0.14))
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(red: 0.78, green: 0.80, blue: 0.82))
                .frame(height: 1)
        }
    }

    private func countLabel(_ book: LogBook) -> String {
        let n = snapshot.count(for: book)
        if book == .anchorHandling {
            return n == 1 ? "1 move" : "\(n) moves"
        }
        return "\(n)"
    }

    private func hoursLabel(_ book: LogBook) -> String {
        switch book {
        case .anchorHandling:
            return ExportSnapshot.hoursText(snapshot.anchorHours)
        case .dp:
            return ExportSnapshot.hoursText(snapshot.dpHours)
        case .rov:
            return ExportSnapshot.hoursText(snapshot.rovHours)
        case .crane:
            return ExportSnapshot.hoursText(snapshot.craneHours)
        }
    }

    private var dividerHeavy: some View {
        Rectangle()
            .fill(Color(red: 0.051, green: 0.086, blue: 0.114))
            .frame(height: 1.5)
            .padding(.top, 4)
    }
}
