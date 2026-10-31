import SwiftUI

/// Straight, choke, and basket marks for the Slinging & Rigging hitch control.
/// Drawn on the same 24-point grid as the other Tools marks, stroke about 1.78, round caps.
/// Traced from the locked icon sheet: ring and two legs, standing part through the eye,
/// both parts up to the hook with a cradle under the load.
struct HitchIcon: View {
    var hitch: RiggingMath.Hitch
    var side: CGFloat

    var body: some View {
        glyph
            .frame(width: side, height: side)
            .accessibilityHidden(true)
    }

    private var lineWidth: CGFloat { max(1.15, side * 1.78 / 24) }

    @ViewBuilder private var glyph: some View {
        let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        switch hitch {
        case .straight:
            HitchStraightShape().stroke(style: style)
        case .choke:
            HitchChokeShape().stroke(style: style)
        case .basket:
            HitchBasketShape().stroke(style: style)
        }
    }
}

/// Icon beside the name. From xxxLarge the name sits under the icon. Hit target is at least 44 points.
/// Same track as `ToolSegmentBar`: picker fill, field border, teal selection, on-teal ink.
struct HitchSegmentBar: View {
    @Binding var selection: RiggingMath.Hitch
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .footnote) private var iconSide: CGFloat = 20

    private var wrapLabel: Bool { dynamicTypeSize >= .xxxLarge }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 4) { cells }
            } else {
                HStack(spacing: 4) { cells }
            }
        }
        .padding(3)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(AppTheme.pickerFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AppTheme.fieldBorder, lineWidth: 1)
        }
    }

    private var cells: some View {
        ForEach(RiggingMath.Hitch.allCases) { hitch in
            cell(hitch)
        }
    }

    private func cell(_ hitch: RiggingMath.Hitch) -> some View {
        let selected = selection == hitch
        return Button {
            selection = hitch
        } label: {
            label(hitch, selected: selected)
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(AppTheme.teal)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(hitch.rawValue)
        .accessibilityAddTraits(selected ? AccessibilityTraits.isSelected : AccessibilityTraits())
        .accessibilityIdentifier("rigging.hitch.\(hitch.rawValue)")
    }

    @ViewBuilder
    private func label(_ hitch: RiggingMath.Hitch, selected: Bool) -> some View {
        if wrapLabel {
            VStack(spacing: 2) {
                mark(hitch, selected: selected)
                name(hitch, selected: selected)
            }
        } else {
            HStack(spacing: 6) {
                mark(hitch, selected: selected)
                name(hitch, selected: selected)
            }
        }
    }

    private func mark(_ hitch: RiggingMath.Hitch, selected: Bool) -> some View {
        HitchIcon(hitch: hitch, side: iconSide)
            .foregroundStyle(selected ? AppTheme.onTeal : AppTheme.teal)
    }

    private func name(_ hitch: RiggingMath.Hitch, selected: Bool) -> some View {
        Text(hitch.rawValue)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(selected ? AppTheme.onTeal : AppTheme.textPrimary)
            .lineLimit(1)
            .truncationMode(.tail)
            .multilineTextAlignment(.center)
    }
}

// MARK: - 24-point paths

private struct HitchGrid {
    let scale: CGFloat
    let point: (CGFloat, CGFloat) -> CGPoint

    init(_ rect: CGRect) {
        let scale = min(rect.width, rect.height) / 24
        let originX = rect.minX + (rect.width - 24 * scale) / 2
        let originY = rect.minY + (rect.height - 24 * scale) / 2
        self.scale = scale
        point = { x, y in CGPoint(x: originX + x * scale, y: originY + y * scale) }
    }

    func ring(_ path: inout Path, _ x: CGFloat, _ y: CGFloat, _ radius: CGFloat) {
        let center = point(x, y)
        let r = radius * scale
        path.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
    }

    func line(_ path: inout Path, _ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
        path.move(to: point(x1, y1))
        path.addLine(to: point(x2, y2))
    }

    func rounded(_ path: inout Path, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ radius: CGFloat) {
        let origin = point(x, y)
        path.addRoundedRect(
            in: CGRect(x: origin.x, y: origin.y, width: width * scale, height: height * scale),
            cornerSize: CGSize(width: radius * scale, height: radius * scale)
        )
    }
}

/// Hook ring, two open legs, load pads.
private struct HitchStraightShape: Shape {
    func path(in rect: CGRect) -> Path {
        let g = HitchGrid(rect)
        var path = Path()
        g.ring(&path, 12, 3.55, 1.7)
        g.line(&path, 12, 5.35, 12, 7.05)
        g.line(&path, 12, 7.05, 6.9, 18.35)
        g.line(&path, 12, 7.05, 17.1, 18.35)
        g.line(&path, 4.9, 19.15, 8.3, 19.15)
        g.line(&path, 15.7, 19.15, 19.1, 19.15)
        return path
    }
}

/// Hook, standing part through the eye, load under the bite.
private struct HitchChokeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let g = HitchGrid(rect)
        var path = Path()
        g.ring(&path, 12, 3.3, 1.55)
        g.line(&path, 12, 4.95, 12, 14.55)
        g.ring(&path, 12, 9.2, 2.55)
        g.rounded(&path, 7.7, 14.55, 8.6, 6.0, 1.35)
        return path
    }
}

/// Both parts up to the hook, cradle under the rectangular load.
private struct HitchBasketShape: Shape {
    func path(in rect: CGRect) -> Path {
        let g = HitchGrid(rect)
        var path = Path()
        g.ring(&path, 12, 3.15, 1.55)
        g.line(&path, 12, 4.8, 12, 6.25)
        path.move(to: g.point(12, 6.25))
        path.addLine(to: g.point(6.4, 9.1))
        path.addLine(to: g.point(6.4, 15.7))
        path.addCurve(to: g.point(17.6, 15.7), control1: g.point(6.4, 20.9), control2: g.point(17.6, 20.9))
        path.addLine(to: g.point(17.6, 9.1))
        path.addLine(to: g.point(12, 6.25))
        g.rounded(&path, 8.8, 9.85, 6.4, 5.0, 0.6)
        return path
    }
}

#Preview("Hitch cells") {
    HitchSegmentPreview()
}

private struct HitchSegmentPreview: View {
    @State private var hitch = RiggingMath.Hitch.straight

    var body: some View {
        ZStack {
            AppCanvas()
            HitchSegmentBar(selection: $hitch)
                .padding(16)
        }
        .preferredColorScheme(.dark)
    }
}
