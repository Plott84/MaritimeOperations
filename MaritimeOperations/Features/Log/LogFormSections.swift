import SwiftUI

// Shared pieces for the ROV and Crane books and forms. Built from the AH components
// (AHSectionCard, AHFieldRow, AHValueText, AHChip, AHFlowLayout, AHTag) and copied from the
// AH form/book so all books look and behave the same. Identifiers use the book's prefix
// ("rov", "crane") in the AH style: rovVessel, rovPositionPicker, craneSave, …

// MARK: - When

/// Start, End and the calculated Duration well. Same layout as the AH form's "When" card.
struct LogWhenCard: View {
    @Binding var start: Date
    @Binding var end: Date
    /// Identifier prefix, e.g. "rov" → rovStart, rovEnd, rovDuration.
    let idPrefix: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        AHSectionCard(title: "When", systemImage: "calendar") {
            AHFieldRow(title: "Start") {
                DatePicker("Start", selection: $start, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .accessibilityLabel("Start")
                    .accessibilityIdentifier("\(idPrefix)Start")
            }
            AHFieldRow(title: "End") {
                DatePicker("End", selection: $end, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .accessibilityLabel("End")
                    .accessibilityIdentifier("\(idPrefix)End")
            }
            durationLayout {
                Label {
                    Text("Duration")
                } icon: {
                    Image(systemName: "clock")
                        .accessibilityHidden(true)
                }
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: 8)
                }
                HStack(spacing: 8) {
                    Text(durationCopy)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("\(idPrefix)Duration")
                    AHTag(title: "auto")
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(AppTheme.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            .padding(.top, 8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Duration, \(durationCopy), calculated")
        }
    }

    private var durationLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(spacing: 8))
    }

    private var durationCopy: String {
        AHFormat.duration(start: start, end: end) ?? "End is before start"
    }
}

// MARK: - Job rows

/// Inline text field on the right of an AHFieldRow (left-aligned at Accessibility sizes).
struct LogInlineTextField: View {
    let title: String
    @Binding var text: String
    var prompt = "Not set"
    let identifier: String
    var focus: FocusState<Bool>.Binding
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        TextField(title, text: $text, prompt: Text(prompt).foregroundStyle(AppTheme.textSecondary))
            .textFieldStyle(.plain)
            .textInputAutocapitalization(.words)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.textPrimary)
            .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
            .focused(focus)
            .accessibilityIdentifier(identifier)
    }
}

/// Vessel row: text field plus "Pick a logged ship" (ships from all four books).
struct LogVesselRow: View {
    @Binding var vessel: String
    let shipNames: [String]
    let idPrefix: String
    var focus: FocusState<Bool>.Binding
    @State private var showShipPicker = false

    var body: some View {
        AHFieldRow(title: "Vessel") {
            HStack(spacing: 8) {
                LogInlineTextField(title: "Vessel", text: $vessel, identifier: "\(idPrefix)Vessel", focus: focus)
                if !shipNames.isEmpty {
                    Button {
                        showShipPicker = true
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Pick a logged ship")
                    .accessibilityIdentifier("\(idPrefix)PickLoggedShip")
                }
            }
        }
        .sheet(isPresented: $showShipPicker) {
            ShipPickerSheet(names: shipNames) { name in
                vessel = name
            }
        }
    }
}

/// Position menu for any LogPositionChoice list (CrewRank for Crane, ROVGrade for ROV), stored
/// as its raw value ("" = grey "Not set"). A value not in the list (older data) still shows.
struct LogPositionRow<Choice: LogPositionChoice>: View {
    @Binding var raw: String
    let options: [Choice]
    let idPrefix: String

    private var selected: Choice? { options.first { $0.rawValue == raw } }

    var body: some View {
        AHFieldRow(title: "Position") {
            Menu {
                Picker("Position", selection: $raw) {
                    Text("Not set").tag("")
                    if !raw.isEmpty, selected == nil {
                        Text(raw).tag(raw)
                    }
                    ForEach(options) { value in
                        Text(value.pickerLabel).tag(value.rawValue)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    AHValueText(value: selected?.pickerLabel ?? raw)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .accessibilityLabel("Position")
            .accessibilityValue(raw.isEmpty ? "Not set" : (selected?.spokenName ?? raw))
            .accessibilityIdentifier("\(idPrefix)PositionPicker")
        }
    }
}

/// Text row shown under a picker while "Other" is picked. Save stays disabled while it's blank.
struct LogOtherTextRow: View {
    let title: String
    @Binding var text: String
    let identifier: String
    var focus: FocusState<Bool>.Binding

    var body: some View {
        AHFieldRow(title: title) {
            LogInlineTextField(title: title, text: $text, prompt: "Required", identifier: identifier, focus: focus)
                .accessibilityHint("Required while Other is picked.")
        }
    }
}

/// Menu picker for an optional enum (e.g. Crane type). Grey "Not set" when nil.
struct LogMenuPicker<Option: Identifiable & Hashable>: View {
    let title: String
    let options: [Option]
    @Binding var selection: Option?
    let label: (Option) -> String
    var spokenLabel: ((Option) -> String)? = nil
    let identifier: String

    var body: some View {
        Menu {
            Picker(title, selection: $selection) {
                Text("Not set").tag(Option?.none)
                ForEach(options) { option in
                    Text(label(option)).tag(Option?.some(option))
                }
            }
        } label: {
            HStack(spacing: 4) {
                AHValueText(value: selection.map(label))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .accessibilityLabel(title)
        .accessibilityValue(selection.map { spokenLabel?($0) ?? label($0) } ?? "Not set")
        .accessibilityIdentifier(identifier)
    }
}

/// Small grey caption label above a control ("Job type", "Lift type").
struct LogFieldCaption: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Small grey note under a field ("Name only. No coordinates.").
struct LogFieldNote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(AppTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Choices

/// Single choice that wraps onto more lines (ROV job type, Crane mode). Selected = teal fill,
/// a second tap clears it back to "not set". Full-width stacked list at Accessibility sizes.
struct LogChoiceFlow<Option: Identifiable & Hashable>: View {
    let options: [Option]
    @Binding var selection: Option?
    let label: (Option) -> String
    var spokenLabel: ((Option) -> String)? = nil
    let identifier: (Option) -> String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 4) {
                    ForEach(options) { option in
                        button(option, fullWidth: true)
                    }
                }
            } else {
                AHFlowLayout(spacing: 4) {
                    ForEach(options) { option in
                        button(option, fullWidth: false)
                    }
                }
            }
        }
        .padding(3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }

    private func button(_ option: Option, fullWidth: Bool) -> some View {
        let selected = selection == option
        return Button {
            selection = selected ? nil : option
        } label: {
            Text(label(option))
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 36)
                .padding(.horizontal, 12)
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
        .accessibilityHint(selected ? "Double-tap to clear." : "")
        .accessibilityIdentifier(identifier(option))
    }
}

/// Multi-select chips (ROV tasks, Crane lift types), wrapping. Uses AHChip.
struct LogChipSet<Option: Identifiable & Hashable>: View {
    let options: [Option]
    @Binding var selection: Set<Option>
    let label: (Option) -> String
    var spokenLabel: ((Option) -> String)? = nil
    let identifier: (Option) -> String

    var body: some View {
        AHFlowLayout(spacing: 8) {
            ForEach(options) { option in
                AHChip(
                    title: label(option),
                    spokenTitle: spokenLabel?(option),
                    isOn: selection.contains(option),
                    identifier: identifier(option)
                ) {
                    if selection.contains(option) {
                        selection.remove(option)
                    } else {
                        selection.insert(option)
                    }
                }
            }
        }
    }
}

// MARK: - Remarks

struct LogRemarksField: View {
    @Binding var text: String
    let identifier: String
    var focus: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LogFieldCaption(title: "Remarks")
            TextField("Remarks", text: $text, prompt: Text("Own notes, in your own words").foregroundStyle(AppTheme.textSecondary), axis: .vertical)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.sentences)
                .lineLimit(3...8)
                .focused(focus)
                .padding(12)
                .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                }
                .accessibilityIdentifier(identifier)
        }
        .padding(.top, 6)
    }
}

// MARK: - Form header

/// Small book line under the form title ("ROV" with its icon).
struct LogFormBookHeader: View {
    let book: LogBook

    var body: some View {
        Label {
            Text(book.title)
        } icon: {
            LogBookIcon(book: book, scale: 0.8)
                .foregroundStyle(AppTheme.teal)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(AppTheme.textPrimary.opacity(0.85))
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(book.spokenTitle) book")
    }
}

// MARK: - Book screen pieces

/// Header card at the top of a book: caps eyebrow, title, row count, "New entry" pill.
struct LogBookHeaderCard: View {
    let book: LogBook
    let heading: String
    let count: Int
    let idPrefix: String
    let addLabel: String
    var onAdd: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label {
                    Text(book.title.uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(1.1)
                } icon: {
                    LogBookIcon(book: book, scale: 0.75)
                }
                .foregroundStyle(AppTheme.teal)
                .accessibilityAddTraits(.isHeader)

                HStack(alignment: .firstTextBaseline) {
                    Text(heading)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 8)
                    Text(LogBookStats.entriesText(count))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.3), in: Capsule())
                        .overlay(Capsule().stroke(AppTheme.border, lineWidth: 1))
                        .accessibilityIdentifier("\(idPrefix)RowCount")
                }
                Text("Newest first.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)

                Button(action: onAdd) {
                    Label("New entry", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.textPrimary)
                .background(Color.black.opacity(0.28), in: Capsule())
                .overlay(Capsule().stroke(AppTheme.teal.opacity(0.45), lineWidth: 1))
                .accessibilityLabel(addLabel)
                .accessibilityIdentifier("\(idPrefix)AddEntryPill")
            }
        }
    }
}

/// One row in a book list. Badge hidden at Accessibility sizes; lines stack instead of truncating.
struct LogBookRow: View {
    let book: LogBook
    let title: String
    let date: Date
    /// "Vessel B · ROV System A", or empty for grey "Not set".
    let detail: String
    /// "3.5 h piloting"; nil hides it.
    let hoursText: String?
    let spokenLabel: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
        HStack(alignment: .center, spacing: 12) {
            LogBookBadge(book: book)

            VStack(alignment: .leading, spacing: 4) {
                layout {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !stacked { Spacer(minLength: 8) }
                    Text(date.formatted(.dateTime.day().month(.abbreviated).year()))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                layout {
                    Text(detail.isEmpty ? "Not set" : detail)
                        .font(.subheadline)
                        .foregroundStyle(detail.isEmpty ? AppTheme.textSecondary : AppTheme.teal)
                        .fixedSize(horizontal: false, vertical: true)
                    if !stacked { Spacer(minLength: 8) }
                    if let hoursText {
                        Label(hoursText, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
                .accessibilityHidden(true)
        }
        .padding(12)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.teal.opacity(0.28), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel)
        .accessibilityHint("Opens the entry.")
    }
}

/// "Export <book>" row, disabled until Export is built (same as the AH book).
struct LogBookExportRow: View {
    let book: LogBook
    let idPrefix: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "doc.text")
                    .accessibilityHidden(true)
                Text("Export \(book.title)")
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(AppTheme.textSecondary)
            .padding(14)
            .frame(minHeight: 44)
            .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Export \(book.spokenTitle)")
            .accessibilityValue("Not available yet")
            .accessibilityIdentifier("\(idPrefix)ExportBook")
            Text("Exports this book only. Export comes in a later build.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Spoken hours for a row: "3.5 h" → "3.5 hours".
enum LogSpoken {
    static func hours(_ hours: Double) -> String {
        AppFormatters.hoursString(hours).replacingOccurrences(of: " h", with: " hours")
    }
}

// MARK: - Delete confirmation

extension View {
    /// Swipe-delete confirmation, same copy and behaviour as DP and Anchor handling:
    /// Delete removes the row, Cancel keeps it. Identifiers: confirmDelete<Suffix>, cancelDelete<Suffix>.
    func logDeleteConfirmation<Item>(
        pending: Binding<Item?>,
        idSuffix: String,
        onDelete: @escaping (Item) -> Void
    ) -> some View {
        alert(
            DeleteEntryPrompt.confirm,
            isPresented: Binding(
                get: { pending.wrappedValue != nil },
                set: { if !$0 { pending.wrappedValue = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                guard let item = pending.wrappedValue else { return }
                onDelete(item)
                pending.wrappedValue = nil
            }
            .accessibilityIdentifier("confirmDelete\(idSuffix)")
            Button("Cancel", role: .cancel) {
                pending.wrappedValue = nil
            }
            .accessibilityIdentifier("cancelDelete\(idSuffix)")
        }
    }
}
