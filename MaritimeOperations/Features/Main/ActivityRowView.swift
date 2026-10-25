import SwiftUI

struct ActivityRowView: View {
    let item: HomeActivityItem
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        HStack(alignment: .top, spacing: 10) {
            LogBookBadge(book: item.book)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.teal)
                        .lineLimit(stacked ? nil : 1)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(item.trailing)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(stacked ? .leading : .trailing)
                .fixedSize(horizontal: false, vertical: true)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }
}
