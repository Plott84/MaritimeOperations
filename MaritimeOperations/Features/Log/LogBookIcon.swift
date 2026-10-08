import SwiftUI

// Drawn book icons for ROV and Crane (SF Symbols has neither), traced from Pixel's mock
// (catenary/form_kit.py I_ROV / I_CRANE, 24-point grid). Same pattern as AnchorIcon:
// they scale with Dynamic Type like a symbol, and are hidden from VoiceOver.

/// The icon of a book: SF Symbol for DP, drawn icon for the others.
struct LogBookIcon: View {
    let book: LogBook
    var scale: CGFloat = 1

    var body: some View {
        switch book {
        case .dp:
            Image(systemName: book.systemImage ?? "location.north")
                .accessibilityHidden(true)
        case .anchorHandling:
            AnchorIcon(scale: scale)
        case .rov:
            ROVIcon(scale: scale)
        case .crane:
            CraneIcon(scale: scale)
        }
    }
}

/// `fixedSize` set → that many points regardless of Dynamic Type (badges); nil → scales like a symbol.
struct ROVIcon: View {
    @ScaledMetric(relativeTo: .body) private var base: CGFloat = 17
    var scale: CGFloat = 1
    var fixedSize: CGFloat? = nil

    var body: some View {
        let side = fixedSize ?? base * scale
        ROVShape()
            .stroke(style: StrokeStyle(lineWidth: max(1.3, side * 0.075), lineCap: .round, lineJoin: .round))
            .frame(width: side, height: side)
            .accessibilityHidden(true)
    }
}

struct CraneIcon: View {
    @ScaledMetric(relativeTo: .body) private var base: CGFloat = 17
    var scale: CGFloat = 1
    var fixedSize: CGFloat? = nil

    var body: some View {
        let side = fixedSize ?? base * scale
        CraneShape()
            .stroke(style: StrokeStyle(lineWidth: max(1.3, side * 0.075), lineCap: .round, lineJoin: .round))
            .frame(width: side, height: side)
            .accessibilityHidden(true)
    }
}

/// Small 36-point book badge (Main's "Your books" rows and the ROV / Crane book rows).
/// Default sizes: the book's letters ("DP", "AH", "ROV", "CR"), unchanged.
/// Accessibility sizes: ROV and Crane show their drawn icon at a fixed 18 points instead
/// (like the DP crosshair badge in ActivityRowView); DP and AH keep their letters.
/// Always hidden from VoiceOver: every row that shows it already names the book or sits in it.
struct LogBookBadge: View {
    let book: LogBook
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize, book == .rov {
                ROVIcon(fixedSize: 18)
                    .foregroundStyle(AppTheme.teal)
            } else if dynamicTypeSize.isAccessibilitySize, book == .crane {
                CraneIcon(fixedSize: 18)
                    .foregroundStyle(AppTheme.teal)
            } else {
                Text(book.badge)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
        .frame(width: 36, height: 36)
        .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// Mock path on a 24 × 24 grid, scaled into `rect`.
private func grid(_ rect: CGRect) -> (CGFloat, CGFloat) -> CGPoint {
    let s = min(rect.width, rect.height) / 24
    let ox = rect.minX + (rect.width - 24 * s) / 2
    let oy = rect.minY + (rect.height - 24 * s) / 2
    return { x, y in CGPoint(x: ox + x * s, y: oy + y * s) }
}

struct ROVShape: Shape {
    func path(in rect: CGRect) -> Path {
        let pt = grid(rect)
        let s = min(rect.width, rect.height) / 24
        var p = Path()
        // Lift point
        p.move(to: pt(12, 2.5))
        p.addLine(to: pt(12, 6.5))
        // Float pack (top) and frame (bottom)
        let top = CGRect(origin: pt(5, 6.5), size: CGSize(width: 14 * s, height: 5 * s))
        p.addRoundedRect(in: top, cornerSize: CGSize(width: 1.6 * s, height: 1.6 * s))
        let body = CGRect(origin: pt(5, 11.5), size: CGSize(width: 14 * s, height: 6.5 * s))
        p.addRoundedRect(in: body, cornerSize: CGSize(width: 1 * s, height: 1 * s))
        // Camera and light bar
        let cam = pt(9, 14.8)
        p.addEllipse(in: CGRect(x: cam.x - 1.2 * s, y: cam.y - 1.2 * s, width: 2.4 * s, height: 2.4 * s))
        p.move(to: pt(13, 14.8))
        p.addLine(to: pt(16.5, 14.8))
        return p
    }
}

struct CraneShape: Shape {
    func path(in rect: CGRect) -> Path {
        let pt = grid(rect)
        var p = Path()
        // Pedestal and base
        p.move(to: pt(6, 21))
        p.addLine(to: pt(6, 11))
        p.addLine(to: pt(10, 11))
        p.addLine(to: pt(10, 21))
        p.move(to: pt(4, 21))
        p.addLine(to: pt(12, 21))
        // Knuckle boom
        p.move(to: pt(8, 11))
        p.addLine(to: pt(14, 5))
        p.addLine(to: pt(20, 7))
        // Wire and hook
        p.move(to: pt(20, 7))
        p.addLine(to: pt(20, 13))
        p.move(to: pt(18.5, 13.2))
        p.addQuadCurve(to: pt(20, 16), control: pt(18.5, 16))
        p.addQuadCurve(to: pt(21.5, 14.5), control: pt(21.5, 16))
        return p
    }
}
