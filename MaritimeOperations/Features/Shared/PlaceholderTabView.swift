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
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                TealCircleButton(systemImage: "plus") {}
                    .disabled(true)
                    .accessibilityLabel("Add")
            }
        }
    }
}
