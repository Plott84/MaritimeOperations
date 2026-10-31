import SwiftUI

struct WinchCapacityToolView: View {
    // Bindings stay Strings. Placeholders are hints only — not counted until typed.
    // Empty free space → math default 400; typed 0 = full drum.
    @State private var dText = ""
    @State private var d0Text = ""
    @State private var wText = ""
    @State private var dfText = ""
    @State private var freeText = ""
    @State private var deadText = "3"
    @State private var pullText = ""
    /// Live result snapshot — recomputed on every keystroke and on keyboard Done.
    @State private var eval = Eval(outcome: nil, errorField: nil, errorReason: nil, showPull: false)
    @State private var loadState = NamedWinchLoadState()
    @State private var showSave = false
    @State private var showLoad = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private enum Field: Hashable {
        case d, d0, w, df, free, dead, pull
    }

    /// Keyboard focus — HOW TO MEASURE callouts jump straight to the matching input.
    @FocusState private var focusedField: Field?

    /// Drum diagram callout → existing input key (wireDia=d, barrelD0=d0, drumWidthW=w, flangeDf=df, freeSpace=free).
    private func focusKey(for callout: WinchDrumCallout) -> Field {
        switch callout {
        case .wireDia: return .d
        case .barrelD0: return .d0
        case .drumWidthW: return .w
        case .flangeDf: return .df
        case .freeSpace: return .free
        }
    }

    private struct Eval {
        var outcome: WinchCapacityMath.Outcome?
        var errorField: Field?
        var errorReason: String?
        var showPull: Bool
    }

    private func recompute() {
        eval = Self.makeEval(
            dText: dText,
            d0Text: d0Text,
            wText: wText,
            dfText: dfText,
            freeText: freeText,
            deadText: deadText,
            pullText: pullText
        )
    }

    private static func makeEval(
        dText: String,
        d0Text: String,
        wText: String,
        dfText: String,
        freeText: String,
        deadText: String,
        pullText: String
    ) -> Eval {
        // Incomplete required fields → dash, no error tint.
        guard let d = ToolsParse.double(dText),
              let D0 = ToolsParse.double(d0Text),
              let W = ToolsParse.double(wText) else {
            return Eval(outcome: nil, errorField: nil, errorReason: nil, showPull: false)
        }

        let dfTrim = dfText.trimmingCharacters(in: .whitespacesAndNewlines)
        let Df: Double?
        if dfTrim.isEmpty {
            Df = nil
        } else if let v = ToolsParse.double(dfText) {
            Df = v
        } else {
            return Eval(outcome: .invalid(reason: "Check flange size"), errorField: .df, errorReason: "Check flange size", showPull: false)
        }

        // Free space: empty UI → pass 400; typed 0 = full drum.
        let freeTrim = freeText.trimmingCharacters(in: .whitespacesAndNewlines)
        let freeSpace: Double
        if freeTrim.isEmpty {
            freeSpace = WinchCapacityMath.defaultFreeSpaceMm
        } else if let v = ToolsParse.double(freeText) {
            freeSpace = v
        } else {
            return Eval(outcome: .invalid(reason: "Check free space"), errorField: .free, errorReason: "Check free space", showPull: false)
        }

        let deadTrim = deadText.trimmingCharacters(in: .whitespacesAndNewlines)
        let dead: Int
        if deadTrim.isEmpty {
            dead = WinchCapacityMath.defaultDeadWraps
        } else if let v = ToolsParse.double(deadText), v == floor(v), v >= 0, v < Double(Int.max) {
            dead = Int(v)
        } else {
            return Eval(outcome: .invalid(reason: "deadWraps must be ≥ 0."), errorField: .dead, errorReason: "deadWraps must be ≥ 0.", showPull: false)
        }

        // Optional 1st-layer pull: empty → hide pull section; bad → Check 1st layer pull
        let pullTrim = pullText.trimmingCharacters(in: .whitespacesAndNewlines)
        let F1: Double?
        let showPull: Bool
        if pullTrim.isEmpty {
            F1 = nil
            showPull = false
        } else if let v = ToolsParse.double(pullText) {
            F1 = v
            showPull = true
        } else {
            return Eval(outcome: .invalid(reason: "Check 1st layer pull"), errorField: .pull, errorReason: "Check 1st layer pull", showPull: true)
        }

        // Need Df or we cannot compute (math requires flange and/or maxLayers).
        if Df == nil {
            return Eval(outcome: nil, errorField: nil, errorReason: nil, showPull: showPull)
        }

        let outcome = WinchCapacityMath.capacity(
            ropeDiameter: d,
            barrelDiameter: D0,
            drumWidth: W,
            flangeDiameter: Df,
            deadWraps: dead,
            freeSpaceMm: freeSpace,
            firstLayerPullTonnes: F1
        )

        var field: Field?
        var reason: String?
        if case .invalid(let r) = outcome {
            reason = r
            switch r {
            case "Check wire size": field = .d
            case "Check barrel size": field = .d0
            case "Check drum width": field = .w
            case "Check flange size": field = .df
            case "Check free space": field = .free
            case "Check 1st layer pull": field = .pull
            default: field = .d
            }
        }

        return Eval(outcome: outcome, errorField: field, errorReason: reason, showPull: showPull)
    }

    /// Joined field text. Load/save records this snapshot; a later edit clears the Loaded chip.
    private var fieldFingerprint: String {
        [dText, d0Text, wText, dfText, freeText, deadText, pullText].joined(separator: "\u{1f}")
    }

    private var capturedInputs: NamedWinchInputs? {
        NamedWinchInputs.capture(
            wire: dText,
            barrel: d0Text,
            width: wText,
            flange: dfText,
            freeSpace: freeText,
            deadWraps: deadText,
            firstLayerPull: pullText
        )
    }

    private func apply(_ preset: NamedWinchPreset) {
        let text = preset.inputs.fieldText
        dText = text.wire
        d0Text = text.barrel
        wText = text.width
        dfText = text.flange
        freeText = text.freeSpace
        deadText = text.deadWraps
        pullText = text.firstLayerPull
        // Same update as the fields, so the fingerprint onChange sees a matching snapshot and keeps the chip.
        loadState.show(name: preset.name, fields: fieldFingerprint)
        recompute()
    }

    /// Tools-tab status line, only for a valid result.
    private var lastResultSummary: String? {
        guard case .ok(let r)? = eval.outcome, r.workingLengthM.isFinite else { return nil }
        return "Last: \(r.workingLengthM.formatted(.number.precision(.fractionLength(0)))) m on drum · \(r.layerCount) layers"
    }

    var body: some View {
        ZStack {
            AppCanvas()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let loadedName = loadState.loadedName {
                            loadedChip(loadedName)
                        }
                        // HOW TO MEASURE card first (Pixel winch3 mock)
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                sectionCaption("HOW TO MEASURE")
                                Text("Drum geometry")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                WinchDrumGeometryDiagram { callout in
                                    let key = focusKey(for: callout)
                                    focusedField = key
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        proxy.scrollTo(key, anchor: .center)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 200)
                                Text("Where the measurements sit on the drum.")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("How to measure drum geometry")

                        GlassCard {
                            VStack(alignment: .leading, spacing: 14) {
                                sectionCaption("DRUM")
                                ToolNumberField(
                                    title: "Wire or rope diameter",
                                    text: $dText,
                                    placeholder: "87",
                                    unit: "mm",
                                    isError: eval.errorField == .d,
                                    errorReason: eval.errorField == .d ? eval.errorReason : nil,
                                    fieldAccessibilityIdentifier: WinchDrumCallout.wireDia.fieldAccessibilityIdentifier
                                )
                                .focused($focusedField, equals: .d)
                                .id(Field.d)
                                ToolNumberField(
                                    title: "Barrel diameter D0",
                                    text: $d0Text,
                                    placeholder: "1800",
                                    unit: "mm",
                                    isError: eval.errorField == .d0,
                                    errorReason: eval.errorField == .d0 ? eval.errorReason : nil,
                                    fieldAccessibilityIdentifier: WinchDrumCallout.barrelD0.fieldAccessibilityIdentifier
                                )
                                .focused($focusedField, equals: .d0)
                                .id(Field.d0)
                                ToolNumberField(
                                    title: "Drum width W",
                                    text: $wText,
                                    placeholder: "3400",
                                    unit: "mm",
                                    isError: eval.errorField == .w,
                                    errorReason: eval.errorField == .w ? eval.errorReason : nil,
                                    fieldAccessibilityIdentifier: WinchDrumCallout.drumWidthW.fieldAccessibilityIdentifier
                                )
                                .focused($focusedField, equals: .w)
                                .id(Field.w)
                                ToolNumberField(
                                    title: "Flange diameter Df",
                                    text: $dfText,
                                    placeholder: "4300",
                                    unit: "mm",
                                    isError: eval.errorField == .df,
                                    errorReason: eval.errorField == .df ? eval.errorReason : nil,
                                    fieldAccessibilityIdentifier: WinchDrumCallout.flangeDf.fieldAccessibilityIdentifier
                                )
                                .focused($focusedField, equals: .df)
                                .id(Field.df)
                                ToolNumberField(
                                    title: "Free space (empty = 400)",
                                    text: $freeText,
                                    placeholder: "400",
                                    unit: "mm",
                                    isError: eval.errorField == .free,
                                    errorReason: eval.errorField == .free ? eval.errorReason : nil,
                                    fieldAccessibilityIdentifier: WinchDrumCallout.freeSpace.fieldAccessibilityIdentifier
                                )
                                .focused($focusedField, equals: .free)
                                .id(Field.free)
                                ToolNumberField(
                                    title: "Dead wraps",
                                    text: $deadText,
                                    placeholder: "3",
                                    unit: nil,
                                    keyboard: .numberPad,
                                    isError: eval.errorField == .dead,
                                    errorReason: eval.errorField == .dead ? eval.errorReason : nil
                                )
                                .focused($focusedField, equals: .dead)
                                .id(Field.dead)
                                ToolNumberField(
                                    title: "1st-layer pull (optional)",
                                    text: $pullText,
                                    placeholder: "170",
                                    unit: "t",
                                    isError: eval.errorField == .pull,
                                    errorReason: eval.errorField == .pull ? eval.errorReason : nil
                                )
                                .focused($focusedField, equals: .pull)
                                .id(Field.pull)
                            }
                        }

                        GlassCard {
                            resultsBlock
                        }

                        Text(NamedWinchCopy.aid)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("winchAid")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle(NamedWinchCopy.navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .systemGlassNavigation()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        ToolsKeyboard.dismiss()
                        showLoad = true
                    } label: {
                        Text(NamedWinchCopy.load)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.teal)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(NamedWinchCopy.loadHint)
                    .accessibilityIdentifier("winchLoad")

                    Button {
                        ToolsKeyboard.dismiss()
                        showSave = true
                    } label: {
                        Text(NamedWinchCopy.save)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.onTeal)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(AppTheme.teal, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(NamedWinchCopy.saveHint)
                    .accessibilityIdentifier("winchSave")
                }
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .toolsKeyboardDone { recompute() }
        .sheet(isPresented: $showSave) {
            WinchSaveSheet(inputs: capturedInputs) { preset in
                loadState.show(name: preset.name, fields: fieldFingerprint)
            }
        }
        .sheet(isPresented: $showLoad) {
            WinchLoadSheet { preset in
                apply(preset)
            }
        }
        .onDisappear {
            // Save once, on leaving, only if a valid result is on screen (not per keystroke).
            if let s = lastResultSummary { ToolLastResultStore().save(s, for: .winch) }
        }
        .onAppear { recompute() }
        .onChange(of: fieldFingerprint) { _, newValue in
            recompute()
            loadState.fieldsChanged(to: newValue)
        }
    }

    private func loadedChip(_ name: String) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(NamedWinchCopy.loaded)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.gold)
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                    .truncationMode(.tail)
                Button {
                    loadState.clearChip()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(NamedWinchCopy.clearLoaded)
                .accessibilityIdentifier("winchLoadedClear")
            }
            .padding(.leading, 12)
            .padding(.trailing, 4)
            .padding(.vertical, 4)
            .background(AppTheme.card, in: Capsule())
            .overlay {
                Capsule().strokeBorder(AppTheme.cardBorder, lineWidth: 1)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("winchLoadedChip")
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var resultsBlock: some View {
        switch eval.outcome {
        case nil:
            ToolResultHero(caption: "WORKING LENGTH", value: ToolsParse.dash, unit: "m")
            ToolResultRow(title: "Layers", value: ToolsParse.dash)
        case .invalid(let reason):
            ToolResultHero(caption: "WORKING LENGTH", value: ToolsParse.dash, unit: "m")
            if eval.errorField == nil {
                Text(reason)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.danger)
            }
        case .ok(let r):
            ToolResultHero(
                caption: "WORKING LENGTH",
                value: ToolsParse.format(r.workingLengthM, decimals: 0),
                unit: "m"
            )
            ToolResultRow(title: "Layers", value: "\(r.layerCount)")
            if r.layersExcessive {
                ToolWarningPill(text: "Check sizes, over 40 layers")
            }
            if eval.showPull {
                if let top = r.topLayerPullTonnes {
                    ToolResultRow(title: "Top-layer pull", value: "\(ToolsParse.format(top, decimals: 0)) t")
                } else {
                    ToolResultRow(title: "Top-layer pull", value: ToolsParse.dash)
                }
            }
        }
    }

    private func sectionCaption(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .tracking(1.1)
            .foregroundStyle(AppTheme.teal)
    }
}
