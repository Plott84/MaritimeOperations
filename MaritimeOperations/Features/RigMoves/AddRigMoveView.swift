import SwiftUI
import SwiftData

struct AddRigMoveView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var rigName = ""
    @State private var date = Date()
    @State private var includeTimes = false
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var operation: RigMoveOperation = .anchorHandling
    @State private var notes = ""
    @State private var isDone = false
    @State private var rigError: String?
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Move") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Rig name", text: $rigName)
                            .textInputAutocapitalization(.words)
                            .onChange(of: rigName) { _, _ in rigError = nil }
                        if let rigError {
                            Text(rigError)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.danger)
                        }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Toggle("Add times", isOn: $includeTimes)
                    if includeTimes {
                        DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                        DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
                    }
                    Picker("Operation", selection: $operation) {
                        ForEach(RigMoveOperation.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    Toggle("Done", isOn: $isDone)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                if let saveError {
                    Section {
                        Text(saveError)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.danger)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Add Rig Move")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func save() {
        let name = rigName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            rigError = "Rig name is required."
            return
        }
        let move = RigMove(
            rigName: name,
            date: date,
            startTime: includeTimes ? startTime : nil,
            endTime: includeTimes ? endTime : nil,
            operation: operation,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            isDone: isDone
        )
        modelContext.insert(move)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.delete(move)
            saveError = "Couldn’t save this rig move. Try again."
        }
    }
}
