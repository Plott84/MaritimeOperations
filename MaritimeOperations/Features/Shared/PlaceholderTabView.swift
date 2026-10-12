import SwiftUI

struct PlaceholderTabView: View {
    let title: String
    let subtitle: String

    var body: some View {
        ZStack {
            AppCanvas()
            VStack(spacing: 12) {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .systemGlassNavigation()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {} label: {
                    Image(systemName: "plus")
                }
                .disabled(true)
                .accessibilityLabel("Add")
            }
        }
    }
}
