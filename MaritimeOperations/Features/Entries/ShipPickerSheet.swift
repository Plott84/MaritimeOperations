import SwiftUI

/// Searchable list of ships already logged, most recently used first. Tap one to use it.
struct ShipPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let names: [String]
    let onPick: (String) -> Void

    @State private var query = ""

    private var filtered: [String] {
        ShipNameSuggestions.filter(names, query: query)
    }

    var body: some View {
        NavigationStack {
            List {
                if filtered.isEmpty {
                    Text(names.isEmpty ? "No ships logged yet. Type a name on the line." : "No match. Cancel and type the new name.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filtered, id: \.self) { name in
                        Button {
                            onPick(name)
                            dismiss()
                        } label: {
                            Text(name)
                        }
                        .accessibilityIdentifier("shipOption_\(name)")
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search ships")
            .navigationTitle("Logged ships")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("shipPickerCancel")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
