import SwiftUI

/// DP class 1 / 2 / 3. Nil shows blank (older lines).
struct DPClassPicker: View {
    @Binding var level: Int?

    var body: some View {
        DPLineFieldRow(title: "DP class") {
            Picker("DP class", selection: $level) {
                Text("—").tag(Int?.none)
                ForEach(1...3, id: \.self) { value in
                    Text("Class \(value)").tag(Int?.some(value))
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.teal)
            .labelsHidden()
            .accessibilityIdentifier("dpClassPicker")
        }
    }
}

/// Optional rank. "" = none. An unknown stored value is kept as its own option.
struct RankPicker: View {
    @Binding var rank: String

    var body: some View {
        DPLineFieldRow(title: "Rank (optional)") {
            Picker("Rank", selection: $rank) {
                Text("None").tag("")
                if !rank.isEmpty, !CrewRank.dpPickerCases.contains(where: { $0.rawValue == rank }) {
                    Text("Current: \(rank)").tag(rank)
                }
                ForEach(CrewRank.dpPickerCases) { value in
                    Text(value.rawValue).tag(value.rawValue)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.teal)
            .labelsHidden()
            .accessibilityIdentifier("dpRankPicker")
        }
    }
}
