import SwiftUI

/// Save the current seven inputs under a name. Case-insensitive match asks before replace.
struct WinchSaveSheet: View {
    var inputs: NamedWinchInputs?
    var onSaved: (NamedWinchPreset) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFocused: Bool

    private let store = NamedWinchPresetStore()
    @State private var name = ""
    @State private var pendingReplace: String?

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var nameMatch: NamedWinchPresetStore.NameMatch {
        store.match(name: name)
    }

    /// Shown under the caption. Too-long wins over a full library. A full library with an empty field still explains why a new name will not save.
    private var blockReason: String? {
        switch nameMatch {
        case .tooLong:
            return NamedWinchCopy.nameTooLong
        case .libraryFull:
            return NamedWinchCopy.libraryFull
        case .empty:
            return store.all().count >= NamedWinchPresetStore.maxPresets ? NamedWinchCopy.libraryFull : nil
        case .available, .collision:
            return nil
        }
    }

    private var canAttempt: Bool {
        guard inputs != nil, !trimmedName.isEmpty else { return false }
        switch nameMatch {
        case .available, .collision:
            return true
        case .empty, .tooLong, .libraryFull:
            return false
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppCanvas()
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField(
                            "",
                            text: $name,
                            prompt: Text(NamedWinchCopy.namePlaceholder)
                                .foregroundStyle(AppTheme.textSecondary)
                        )
                        .focused($nameFocused)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .foregroundStyle(AppTheme.textPrimary)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .padding(14)
                        .fieldChrome()
                        .onSubmit(attemptSave)
                        .accessibilityLabel("Name")
                        .accessibilityIdentifier("winchPresetName")

                        Text(NamedWinchCopy.saveCaption)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("winchSaveCaption")

                        if let blockReason {
                            Text(blockReason)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.danger)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("winchSaveRejection")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .winchPresetSheetChrome(NamedWinchCopy.saveTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NamedWinchCopy.cancel) { dismiss() }
                        .foregroundStyle(AppTheme.teal)
                        .accessibilityIdentifier("winchSaveCancel")
                }
                .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: attemptSave) {
                        Text(NamedWinchCopy.save)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.onTeal)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(AppTheme.teal, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canAttempt)
                    .opacity(canAttempt ? 1 : 0.4)
                    .accessibilityIdentifier("winchSaveConfirm")
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .alert(
                NamedWinchCopy.replaceTitle(pendingReplace ?? ""),
                isPresented: Binding(
                    get: { pendingReplace != nil },
                    set: { if !$0 { pendingReplace = nil } }
                )
            ) {
                Button(NamedWinchCopy.cancel, role: .cancel) {}
                Button(NamedWinchCopy.replace, role: .destructive) { commit() }
            } message: {
                Text(NamedWinchCopy.replaceBody)
            }
        }
        .presentationBackground(AppTheme.background)
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("winchSaveSheet")
        .onAppear { nameFocused = true }
    }

    private func attemptSave() {
        guard inputs != nil else { return }
        switch store.match(name: name) {
        case .empty, .tooLong, .libraryFull:
            break
        case .available:
            commit()
        case .collision(let existingDisplayName):
            pendingReplace = existingDisplayName
        }
    }

    private func commit() {
        guard let inputs else { return }
        guard let preset = store.save(name: name, inputs: inputs) else { return }
        onSaved(preset)
        dismiss()
    }
}

/// Pick a saved winch. Empty library has the locked copy and no delete affordance.
struct WinchLoadSheet: View {
    var onPick: (NamedWinchPreset) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var store: NamedWinchPresetStore
    @State private var presets: [NamedWinchPreset]

    init(onPick: @escaping (NamedWinchPreset) -> Void, store: NamedWinchPresetStore = NamedWinchPresetStore()) {
        self.onPick = onPick
        self.store = store
        _presets = State(initialValue: store.all())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppCanvas()
                if presets.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(presets.enumerated()), id: \.element.id) { index, preset in
                                if index > 0 {
                                    Divider()
                                        .overlay(AppTheme.cardBorder)
                                        .padding(.leading, 16)
                                }
                                row(preset)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .winchPresetSheetChrome(NamedWinchCopy.loadTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NamedWinchCopy.cancel) { dismiss() }
                        .foregroundStyle(AppTheme.teal)
                        .accessibilityIdentifier("winchLoadCancel")
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
        .presentationBackground(AppTheme.background)
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("winchLoadSheet")
        .onAppear { presets = store.all() }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(NamedWinchCopy.emptyTitle)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("winchLoadEmptyTitle")
            Text(NamedWinchCopy.emptyBody)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("winchLoadEmptyBody")
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(_ preset: NamedWinchPreset) -> some View {
        Button {
            onPick(preset)
            dismiss()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                    Text(preset.dimsSummary)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .monospacedDigit()
                        .multilineTextAlignment(.leading)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.teal)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(preset.name), \(preset.dimsSummary)")
        .accessibilityHint(NamedWinchCopy.loadRowHint)
        .accessibilityIdentifier("winchPresetRow.\(preset.id.uuidString)")
    }
}

private struct WinchPresetSheetChrome: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .tint(AppTheme.teal)
    }
}

fileprivate extension View {
    func winchPresetSheetChrome(_ title: String) -> some View {
        modifier(WinchPresetSheetChrome(title: title))
    }
}
