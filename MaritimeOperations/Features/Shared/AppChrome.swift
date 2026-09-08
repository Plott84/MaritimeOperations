import SwiftUI

struct AppCanvas: View {
    var body: some View {
        ZStack {
            AppTheme.background
            GridOverlay()
            Image(systemName: "location.north.line")
                .font(.system(size: 220, weight: .ultraLight))
                .foregroundStyle(AppTheme.teal.opacity(0.07))
                .rotationEffect(.degrees(12))
                .offset(x: 140, y: -220)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
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

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [AppTheme.teal.opacity(0.75), AppTheme.teal.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.25
                    )
            }
            .shadow(color: AppTheme.teal.opacity(0.16), radius: 14, y: 6)
    }
}

struct TealCircleButton: View {
    let systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.teal)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.black.opacity(0.25)))
                .overlay(Circle().stroke(AppTheme.teal.opacity(0.7), lineWidth: 1.2))
        }
        .buttonStyle(.plain)
    }
}
