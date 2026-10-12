import SwiftUI

struct AppCanvas: View {
    var body: some View {
        ZStack {
            AppTheme.background
            GridOverlay()
            TriangleLineArt()
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}


private struct TriangleLineArt: View {
    var body: some View {
        Canvas { context, size in
            let origin = CGPoint(x: size.width - 28, y: 36)
            var path = Path()
            // Faint geometric triangle, top-right — not a compass icon
            path.move(to: CGPoint(x: origin.x - 150, y: origin.y + 18))
            path.addLine(to: CGPoint(x: origin.x - 20, y: origin.y + 210))
            path.addLine(to: CGPoint(x: origin.x - 90, y: origin.y + 8))
            path.closeSubpath()
            path.move(to: CGPoint(x: origin.x - 118, y: origin.y + 70))
            path.addLine(to: CGPoint(x: origin.x - 48, y: origin.y + 150))
            context.stroke(path, with: .color(AppTheme.teal.opacity(0.10)), lineWidth: 1.2)
        }
    }
}

private struct GridOverlay: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 32
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }
            context.stroke(path, with: .color(Color.white.opacity(0.045)), lineWidth: 0.6)
        }
        .allowsHitTesting(false)
    }
}

/// Solid navy content card. Glass stays on floating chrome (tab bar, toolbars, sheets).
struct GlassCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AppTheme.card)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(AppTheme.cardBorder, lineWidth: 1)
            }
    }
}

extension View {
    /// System navigation bar. A hard scroll-edge fade keeps content from being read under the title.
    func systemGlassNavigation() -> some View {
        self
            .toolbarColorScheme(.dark, for: .navigationBar)
            .scrollEdgeEffectStyle(.hard, for: .top)
    }

    /// Prominent glass Save. Teal tint, label ink from `onTeal`.
    func glassProminentSave() -> some View {
        self
            .buttonStyle(.glassProminent)
            .tint(AppTheme.teal)
            .foregroundStyle(AppTheme.onTeal)
    }

    /// 3:1 stroke for text fields and other boxed controls.
    func fieldChrome(cornerRadius: CGFloat = 12) -> some View {
        background(AppTheme.pickerFill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.fieldBorder, lineWidth: 1)
            }
    }

    /// Compact date/time pickers: same 3:1 field stroke as text fields.
    func datePickerChrome() -> some View {
        padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppTheme.pickerFill, in: Capsule())
            .overlay {
                Capsule().strokeBorder(AppTheme.fieldBorder, lineWidth: 1)
            }
    }
}

/// Off track is the field-border grey; the knob is primary text. On track is teal with on-teal knob.
struct TokenToggleStyle: ToggleStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let isOn = configuration.isOn
        return HStack(alignment: .center, spacing: 12) {
            configuration.label
            Spacer(minLength: 12)
            Capsule()
                .fill(isOn ? AppTheme.teal : AppTheme.toggleOff)
                .frame(width: 52, height: 32)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(isOn ? AppTheme.onTeal : AppTheme.textPrimary)
                        .frame(width: 26, height: 26)
                        .padding(3)
                        .shadow(color: .black.opacity(0.22), radius: 1, y: 1)
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isOn)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            configuration.isOn.toggle()
        }
    }
}
