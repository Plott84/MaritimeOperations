import SwiftUI

// Building blocks for the Anchor handling form and book. Same tokens as the rest of the app:
// GlassCard, AppTheme navy/blue/teal/gold, dark rounded wells.

/// Card with a small teal caps header ("WHEN", "JOB", …).
struct AHSectionCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 4) {
                Label {
                    Text(title.uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(1.1)
                } icon: {
                    Image(systemName: systemImage)
                }
                .foregroundStyle(AppTheme.teal)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 6)
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Label on the left, value on the right. Stacks vertically at Accessibility text sizes
/// so nothing truncates.
struct AHFieldRow<Value: View>: View {
    let title: String
    var showsDivider = true
    @ViewBuilder var value: () -> Value
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        VStack(spacing: 0) {
            layout {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if !stacked {
                    Spacer(minLength: 8)
                }
                value()
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.vertical, 4)
            if showsDivider {
                Rectangle()
                    .fill(AppTheme.border)
                    .frame(height: 1)
            }
        }
    }
}

/// Grey "Not set" or the value, for picker labels.
struct AHValueText: View {
    let value: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let isSet = !(value ?? "").isEmpty
        Text(isSet ? value! : "Not set")
            .font(.subheadline.weight(isSet ? .semibold : .regular))
            .foregroundStyle(isSet ? AppTheme.textPrimary : AppTheme.textSecondary)
            .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Segmented choice. Selected = teal fill. `allowsClear` lets a second tap clear back to nil.
/// Wraps to a vertical list at Accessibility text sizes.
struct AHSegmented<Option: Identifiable & Hashable>: View {
    let options: [Option]
    @Binding var selection: Option?
    var allowsClear = false
    let label: (Option) -> String
    var spokenLabel: ((Option) -> String)? = nil
    let identifier: (Option) -> String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(spacing: 4))
            : AnyLayout(HStackLayout(spacing: 4))
        layout {
            ForEach(options) { option in
                let selected = selection == option
                Button {
                    if selected, allowsClear {
                        selection = nil
                    } else {
                        selection = option
                    }
                } label: {
                    Text(label(option))
                        .font(.subheadline.weight(selected ? .semibold : .regular))
                        .lineLimit(stacked ? nil : 1)
                        .minimumScaleFactor(stacked ? 1 : 0.85)
                        .fixedSize(horizontal: false, vertical: stacked)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .foregroundStyle(selected ? Color.black.opacity(0.85) : AppTheme.textSecondary)
                        .background(
                            selected ? AppTheme.teal : Color.clear,
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(spokenLabel?(option) ?? label(option))
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityHint(selected && allowsClear ? "Double-tap to clear." : "")
                .accessibilityIdentifier(identifier(option))
            }
        }
        .padding(3)
        .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }
}

/// Multi-select chip with a check when on.
struct AHChip: View {
    let title: String
    var spokenTitle: String? = nil
    let isOn: Bool
    let identifier: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                }
                Text(title)
                    .font(.subheadline.weight(isOn ? .semibold : .regular))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(minHeight: 34)
            .foregroundStyle(isOn ? Color.black.opacity(0.85) : AppTheme.textPrimary.opacity(0.85))
            .background(isOn ? AppTheme.teal : Color.black.opacity(0.28), in: Capsule())
            .overlay(Capsule().stroke(isOn ? AppTheme.teal : AppTheme.border, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spokenTitle ?? title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}

/// Left-to-right wrapping layout for chips.
struct AHFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = arrange(subviews: subviews, maxWidth: maxWidth)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = proposal.width ?? rows.map(\.width).max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews: subviews, maxWidth: bounds.width)
        for row in rows {
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y),
                    proposal: ProposedViewSize(item.size)
                )
            }
        }
    }

    private struct Item { let index: Int; let x: CGFloat; let size: CGSize }
    private struct Row { var items: [Item] = []; var y: CGFloat = 0; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        var x: CGFloat = 0
        var y: CGFloat = 0
        for (index, subview) in subviews.enumerated() {
            var size = subview.sizeThatFits(.unspecified)
            if size.width > maxWidth {
                size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
                size.width = min(size.width, maxWidth)
            }
            if x > 0, x + size.width > maxWidth {
                rows.append(current)
                y += current.height + spacing
                current = Row(y: y)
                x = 0
            }
            current.items.append(Item(index: index, x: x, size: size))
            x += size.width + spacing
            current.width = x - spacing
            current.height = max(current.height, size.height)
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}

/// Small dark tile with a caption and a value field ("Water depth / 120 m").
struct AHValueTile<Field: View>: View {
    let title: String
    @ViewBuilder var field: () -> Field

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            field()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }
}

/// Number entry with a unit suffix. Empty = not set.
struct AHNumberField: View {
    let title: String
    let unit: String
    let spokenUnit: String
    @Binding var text: String
    let identifier: String
    var keyboard: UIKeyboardType = .decimalPad

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            TextField(title, text: $text, prompt: Text("—").foregroundStyle(AppTheme.textSecondary))
                .keyboardType(keyboard)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .accessibilityLabel(spokenUnit.isEmpty ? title : "\(title), \(spokenUnit)")
                .accessibilityIdentifier(identifier)
            if !unit.isEmpty {
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .accessibilityHidden(true)
            }
        }
    }
}

/// Small rounded tag, e.g. the "Rig Moves" chip.
struct AHTag: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AppTheme.teal)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(AppTheme.teal.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(AppTheme.teal.opacity(0.55), lineWidth: 1))
    }
}

/// Anchor outline (SF Symbols has no anchor). Scales with Dynamic Type like a symbol.
struct AnchorIcon: View {
    @ScaledMetric(relativeTo: .body) private var base: CGFloat = 17
    var scale: CGFloat = 1

    var body: some View {
        AnchorShape()
            .stroke(style: StrokeStyle(lineWidth: max(1.4, base * scale * 0.11), lineCap: .round, lineJoin: .round))
            .frame(width: base * scale, height: base * scale)
            .accessibilityHidden(true)
    }
}

struct AnchorShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let x = rect.minX
        let y = rect.minY
        let cx = x + w * 0.5
        var p = Path()
        // Ring
        p.addEllipse(in: CGRect(x: cx - w * 0.1, y: y + h * 0.02, width: w * 0.2, height: w * 0.2))
        // Shank
        p.move(to: CGPoint(x: cx, y: y + h * 0.22))
        p.addLine(to: CGPoint(x: cx, y: y + h * 0.96))
        // Stock
        p.move(to: CGPoint(x: x + w * 0.28, y: y + h * 0.36))
        p.addLine(to: CGPoint(x: x + w * 0.72, y: y + h * 0.36))
        // Arms
        let r = w * 0.42
        let centre = CGPoint(x: cx, y: y + h * 0.54)
        p.addArc(center: centre, radius: r, startAngle: .degrees(10), endAngle: .degrees(170), clockwise: false)
        // Flukes
        let left = CGPoint(x: centre.x + r * CGFloat(cos(170 * Double.pi / 180)), y: centre.y + r * CGFloat(sin(170 * Double.pi / 180)))
        let right = CGPoint(x: centre.x + r * CGFloat(cos(10 * Double.pi / 180)), y: centre.y + r * CGFloat(sin(10 * Double.pi / 180)))
        p.move(to: CGPoint(x: left.x - w * 0.02, y: left.y - h * 0.14))
        p.addLine(to: left)
        p.addLine(to: CGPoint(x: left.x + w * 0.13, y: left.y - h * 0.04))
        p.move(to: CGPoint(x: right.x + w * 0.02, y: right.y - h * 0.14))
        p.addLine(to: right)
        p.addLine(to: CGPoint(x: right.x - w * 0.13, y: right.y - h * 0.04))
        return p
    }
}
