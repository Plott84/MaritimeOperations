import SwiftUI

/// Slinging & Rigging. Slings | Chain block. Results update as the fields change.
/// Band table decides Within / Exceeds. Exact trig is information only.
struct SlingingRiggingToolView: View {
    @AppStorage(SlingingRiggingModel.unitStorageKey) private var unitRaw = RiggingMath.MassUnit.tonnes.rawValue
    @State private var model = SlingingRiggingModel()
    private let store = ToolLastResultStore()

    var body: some View {
        ZStack {
            AppCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ToolSegmentBar(
                        title: "Slings or chain block",
                        selection: $model.tab,
                        options: SlingingRiggingModel.Tab.allCases.map { item in
                            ToolSegmentOption(
                                value: item,
                                title: item.rawValue,
                                accessibilityLabel: item.rawValue,
                                accessibilityIdentifier: "rigging.tab.\(item.rawValue)"
                            )
                        }
                    )
                    switch model.tab {
                    case .slings:
                        SlingPane(model: model)
                    case .chain:
                        ChainPane(model: model)
                    }
                    Text(RiggingCopy.footer)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("rigging.footer")
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(RiggingCopy.title)
        .navigationBarTitleDisplayMode(.inline)
        .systemGlassNavigation()
        .toolsKeyboardDone()
        .onAppear { model.applyStoredUnit(unitRaw) }
        .onDisappear {
            if let summary = model.lastResultSummary {
                store.save(summary, for: .rigging)
            }
        }
    }
}

// MARK: - Slings

private struct SlingPane: View {
    @Bindable var model: SlingingRiggingModel

    var body: some View {
        let screen = model.slingScreen
        VStack(alignment: .leading, spacing: 16) {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    eyebrow("INPUTS")
                    unitBar
                    angleModeBar
                    Text(RiggingCopy.angleCaption)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("rigging.angleCaption")
                    legsBar
                    if let note = model.legNote {
                        Label(note, systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("rigging.legNote")
                    }
                    hitchBar
                    if let note = model.chokeNote {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("rigging.chokeCaption")
                    }
                    RiggingField(
                        title: "Load",
                        text: $model.loadText,
                        unit: model.slingUnit.rawValue,
                        systemImage: "scalemass",
                        identifier: "rigging.load",
                        spoken: "Load, \(model.slingUnit.spoken)",
                        error: screen.errors.load
                    )
                    if model.angleMode == .lengthHeight {
                        RiggingField(
                            title: "Sling length L",
                            text: $model.lengthText,
                            unit: "m",
                            systemImage: "ruler",
                            identifier: "rigging.length",
                            spoken: "Sling length L, metres",
                            error: screen.errors.length
                        )
                        RiggingField(
                            title: "Height H",
                            text: $model.heightText,
                            unit: "m",
                            systemImage: "arrow.down.to.line",
                            identifier: "rigging.height",
                            spoken: "Height H, metres",
                            error: screen.errors.height
                        )
                    } else {
                        RiggingField(
                            title: "Angle β",
                            text: $model.angleText,
                            unit: "° from vertical",
                            systemImage: "angle",
                            identifier: "rigging.angle",
                            spoken: "Angle beta, degrees from vertical",
                            error: screen.errors.angle
                        )
                    }
                    if let echo = screen.echo {
                        Text(echo.visible)
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel(echo.spoken)
                            .accessibilityIdentifier("rigging.echo")
                    }
                    RiggingField(
                        title: "Tag WLL per leg",
                        text: $model.tagText,
                        unit: model.slingUnit.rawValue,
                        systemImage: "tag",
                        identifier: "rigging.tag",
                        spoken: "Tag W L L per leg, \(model.slingUnit.spoken)",
                        error: screen.errors.tag
                    )
                }
            }
            resultCard(screen)
        }
    }

    private var unitBar: some View {
        ToolSegmentBar(
            title: "Units",
            selection: Binding(get: { model.slingUnit }, set: { model.setSlingUnit($0) }),
            options: RiggingMath.MassUnit.allCases.map { unit in
                ToolSegmentOption(
                    value: unit,
                    title: unit.rawValue,
                    accessibilityLabel: unit.spoken,
                    accessibilityIdentifier: "rigging.unit.\(unit.rawValue)"
                )
            }
        )
    }

    private var angleModeBar: some View {
        ToolSegmentBar(
            title: "Angle from",
            selection: $model.angleMode,
            options: SlingingRiggingModel.AngleMode.allCases.map { mode in
                ToolSegmentOption(
                    value: mode,
                    title: mode.rawValue,
                    accessibilityLabel: mode.rawValue,
                    accessibilityIdentifier: "rigging.angleMode.\(mode.rawValue)"
                )
            }
        )
    }

    private var legsBar: some View {
        ToolSegmentBar(
            title: "Legs",
            selection: $model.legs,
            options: [1, 2, 3, 4].map { leg in
                ToolSegmentOption(
                    value: leg,
                    title: "\(leg)",
                    accessibilityLabel: "\(leg) legs",
                    accessibilityIdentifier: "rigging.legs.\(leg)"
                )
            }
        )
    }

    private var hitchBar: some View {
        ToolSegmentBar(
            title: "Hitch",
            selection: $model.hitch,
            options: RiggingMath.Hitch.allCases.map { hitch in
                ToolSegmentOption(
                    value: hitch,
                    title: hitch.rawValue,
                    accessibilityLabel: hitch.rawValue,
                    accessibilityIdentifier: "rigging.hitch.\(hitch.rawValue)"
                )
            }
        )
    }

    @ViewBuilder
    private func resultCard(_ screen: SlingingRiggingModel.SlingScreen) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                eyebrow("RESULT")
                switch screen.panel {
                case .guidance(let text):
                    guidance(text)
                case .invalid(let text):
                    invalid(text)
                case .blocked(let text):
                    blocked(text)
                case .sling(let row):
                    slingResult(row)
                case .chainSingle, .chainPair:
                    guidance(RiggingCopy.slingGuidanceLength)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay { cardStroke(screen.panel) }
    }

    private func slingResult(_ row: SlingingRiggingModel.SlingReadout) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STATUS")
                .font(.caption2.weight(.semibold))
                .tracking(1.0)
                .foregroundStyle(AppTheme.textSecondary)
                .accessibilityHidden(true)
            hero(row.hero, within: row.within, spoken: row.heroSpoken)
            readoutRow("Band", row.bandLine, spoken: row.bandSpoken, id: "rigging.band")
            readoutRow("Required tag WLL", row.requiredLine, spoken: row.requiredSpoken, id: "rigging.required")
            readoutRow("Assembly WLL", row.assemblyLine, spoken: row.assemblySpoken, id: "rigging.assembly")
            readoutRow("Tension per leg", row.tensionLine, spoken: row.tensionSpoken, id: "rigging.tension")
            Text(row.trigLine)
                .font(.footnote)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("rigging.trig")
            Text(row.assumptions)
                .font(.footnote)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("rigging.assumptions")
            if let amber = row.amber {
                noteBanner(amber, tone: .amber)
            }
        }
    }
}

// MARK: - Chain block

private struct ChainPane: View {
    @Bindable var model: SlingingRiggingModel

    var body: some View {
        let screen = model.chainScreen
        VStack(alignment: .leading, spacing: 16) {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    eyebrow("INPUTS")
                    unitBar
                    modeBar
                    Text(RiggingCopy.chainAngleCaption)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("rigging.chainCaption")
                    RiggingField(
                        title: "Load",
                        text: $model.chainLoadText,
                        unit: model.chainUnit.rawValue,
                        systemImage: "scalemass",
                        identifier: "rigging.chain.load",
                        spoken: "Load, \(model.chainUnit.spoken)",
                        error: screen.errors.load
                    )
                    if model.chainMode == .single {
                        singleFields(screen)
                    } else {
                        pairFields(screen)
                    }
                }
            }
            chainResult(screen)
        }
    }

    private var unitBar: some View {
        ToolSegmentBar(
            title: "Units",
            selection: Binding(get: { model.chainUnit }, set: { model.setChainUnit($0) }),
            options: RiggingMath.MassUnit.allCases.map { unit in
                ToolSegmentOption(
                    value: unit,
                    title: unit.rawValue,
                    accessibilityLabel: unit.spoken,
                    accessibilityIdentifier: "rigging.unit.\(unit.rawValue)"
                )
            }
        )
    }

    private var modeBar: some View {
        ToolSegmentBar(
            title: "Chain block mode",
            selection: $model.chainMode,
            options: SlingingRiggingModel.ChainMode.allCases.map { mode in
                ToolSegmentOption(
                    value: mode,
                    title: mode.rawValue,
                    accessibilityLabel: mode.rawValue,
                    accessibilityIdentifier: "rigging.chainMode.\(mode.rawValue)"
                )
            }
        )
    }

    @ViewBuilder
    private func singleFields(_ screen: SlingingRiggingModel.ChainScreen) -> some View {
        RiggingField(
            title: "Block WLL",
            text: $model.chainWLLText,
            unit: model.chainUnit.rawValue,
            systemImage: "tag",
            identifier: "rigging.chain.wll",
            spoken: "Block W L L, \(model.chainUnit.spoken)",
            error: screen.errors.blockWLL
        )
        RiggingField(
            title: "Angle β",
            text: $model.chainAngleText,
            unit: "° from vertical",
            systemImage: "angle",
            identifier: "rigging.chain.angle",
            spoken: "Angle beta, degrees from vertical",
            error: screen.errors.angle
        )
        if let echo = screen.echo {
            Text(echo.visible)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(echo.spoken)
                .accessibilityIdentifier("rigging.echo")
        }
    }

    @ViewBuilder
    private func pairFields(_ screen: SlingingRiggingModel.ChainScreen) -> some View {
        RiggingField(
            title: "β₁",
            text: $model.chainBeta1Text,
            unit: "° from vertical",
            systemImage: "angle",
            identifier: "rigging.chain.beta1",
            spoken: "Beta 1, degrees from vertical",
            error: screen.errors.beta1
        )
        RiggingField(
            title: "β₂",
            text: $model.chainBeta2Text,
            unit: "° from vertical",
            systemImage: "angle",
            identifier: "rigging.chain.beta2",
            spoken: "Beta 2, degrees from vertical",
            error: screen.errors.beta2
        )
        RiggingField(
            title: "Block 1 WLL",
            text: $model.chainWLL1Text,
            unit: model.chainUnit.rawValue,
            systemImage: "tag",
            identifier: "rigging.chain.wll1",
            spoken: "Block 1 W L L, \(model.chainUnit.spoken)",
            error: screen.errors.block1,
            titleNote: "optional"
        )
        RiggingField(
            title: "Block 2 WLL",
            text: $model.chainWLL2Text,
            unit: model.chainUnit.rawValue,
            systemImage: "tag",
            identifier: "rigging.chain.wll2",
            spoken: "Block 2 W L L, \(model.chainUnit.spoken)",
            error: screen.errors.block2,
            titleNote: "optional"
        )
    }

    @ViewBuilder
    private func chainResult(_ screen: SlingingRiggingModel.ChainScreen) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                eyebrow("RESULT")
                switch screen.panel {
                case .guidance(let text):
                    guidance(text)
                case .invalid(let text):
                    invalid(text)
                case .blocked(let text):
                    blocked(text)
                case .chainSingle(let row):
                    singleResult(row)
                case .chainPair(let row):
                    pairResult(row)
                case .sling:
                    guidance(RiggingCopy.chainGuidance)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay { cardStroke(screen.panel) }
    }

    private func singleResult(_ row: SlingingRiggingModel.ChainSingleReadout) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STATUS")
                .font(.caption2.weight(.semibold))
                .tracking(1.0)
                .foregroundStyle(AppTheme.textSecondary)
                .accessibilityHidden(true)
            hero(row.hero, within: row.within, spoken: row.heroSpoken)
            readoutRow("Load", row.loadLine, spoken: row.loadSpoken, id: "rigging.chain.loadRow")
            readoutRow("Block WLL", row.wllLine, spoken: row.wllSpoken, id: "rigging.chain.wllRow")
            readoutRow("Angle", row.angleLine, spoken: row.angleSpoken, id: "rigging.chain.angleRow")
            if let note = row.noReduction {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("rigging.noReduction")
            }
            if let amber = row.amber {
                noteBanner(amber, tone: .amber)
            }
        }
    }

    private func pairResult(_ row: SlingingRiggingModel.ChainPairReadout) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STATUS")
                .font(.caption2.weight(.semibold))
                .tracking(1.0)
                .foregroundStyle(AppTheme.textSecondary)
                .accessibilityHidden(true)
            if let heroText = row.hero, let spoken = row.heroSpoken {
                hero(heroText, within: row.within ?? false, spoken: spoken)
            }
            readoutRow("β₁", row.angle1Line, spoken: row.angle1Spoken, id: "rigging.chain.beta1Row")
            readoutRow("β₂", row.angle2Line, spoken: row.angle2Spoken, id: "rigging.chain.beta2Row")
            readoutRow("Tension T₁", row.tension1Line, spoken: row.tension1Spoken, id: "rigging.t1")
            readoutRow("Tension T₂", row.tension2Line, spoken: row.tension2Spoken, id: "rigging.t2")
            if let share = row.share1Line, let spoken = row.share1Spoken {
                readoutRow("Block 1 share", share, spoken: spoken, id: "rigging.share1")
            }
            if let share = row.share2Line, let spoken = row.share2Spoken {
                readoutRow("Block 2 share", share, spoken: spoken, id: "rigging.share2")
            }
            if let hint = row.hint {
                Text(hint)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("rigging.chain.hint")
            }
            noteBanner(row.amber, tone: .amber)
        }
    }
}

// MARK: - Shared pieces

private enum NoteTone { case amber, blocked }

private struct RiggingField: View {
    let title: String
    @Binding var text: String
    var unit: String
    var systemImage: String
    var identifier: String
    var spoken: String
    var error: String?
    var titleNote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(error == nil ? AppTheme.teal : AppTheme.danger)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(error == nil ? AppTheme.textSecondary : AppTheme.danger)
                    .fixedSize(horizontal: false, vertical: true)
                if let titleNote {
                    Text(titleNote)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextField(
                    "",
                    text: $text,
                    prompt: Text(title).foregroundStyle(AppTheme.textSecondary)
                )
                .keyboardType(.decimalPad)
                .textFieldStyle(.plain)
                .foregroundStyle(AppTheme.textPrimary)
                .accessibilityLabel(spoken)
                .accessibilityIdentifier(identifier)
                Text(unit)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .frame(minHeight: 44)
            .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(error == nil ? AppTheme.fieldBorder : AppTheme.danger, lineWidth: error == nil ? 1 : 1.5)
            }
            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("\(identifier).error")
            }
        }
    }
}

private func eyebrow(_ text: String) -> some View {
    Text(text)
        .font(.caption.weight(.bold))
        .tracking(1.1)
        .foregroundStyle(AppTheme.teal)
        .accessibilityAddTraits(.isHeader)
}

private func guidance(_ text: String) -> some View {
    Text(text)
        .font(.footnote)
        .foregroundStyle(AppTheme.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("rigging.guidance")
}

private func invalid(_ text: String) -> some View {
    Label(text, systemImage: "exclamationmark.circle")
        .font(.body)
        .foregroundStyle(AppTheme.textPrimary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("rigging.invalid")
}

private func blocked(_ text: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
        Image(systemName: "xmark.octagon.fill")
            .foregroundStyle(AppTheme.danger)
            .accessibilityHidden(true)
        Text(text)
            .font(.title3.weight(.semibold))
            .foregroundStyle(AppTheme.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(AppTheme.danger.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(AppTheme.danger, lineWidth: 1.5)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Warning. \(text)")
    .accessibilityIdentifier("rigging.blocked")
}

private func hero(_ text: String, within: Bool, spoken: String) -> some View {
    Text(text)
        .font(.title2.weight(.bold))
        .foregroundStyle(within ? AppTheme.teal : AppTheme.gold)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .accessibilityLabel(spoken)
        .accessibilityIdentifier("rigging.hero")
}

private func readoutRow(_ title: String, _ value: String, spoken: String, id: String) -> some View {
    ViewThatFits(in: .horizontal) {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            rowTitle(title)
            Spacer(minLength: 8)
            rowValue(value)
        }
        VStack(alignment: .leading, spacing: 2) {
            rowTitle(title)
            rowValue(value)
        }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(spoken)
    .accessibilityIdentifier(id)
}

private func rowTitle(_ text: String) -> some View {
    Text(text)
        .font(.subheadline)
        .foregroundStyle(AppTheme.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
}

private func rowValue(_ text: String) -> some View {
    Text(text)
        .font(.subheadline.weight(.semibold).monospacedDigit())
        .foregroundStyle(AppTheme.textPrimary)
        .fixedSize(horizontal: false, vertical: true)
        .multilineTextAlignment(.trailing)
}

private func noteBanner(_ text: String, tone: NoteTone) -> some View {
    let color = tone == .amber ? AppTheme.gold : AppTheme.danger
    return VStack(alignment: .leading, spacing: 6) {
        Text("NOTE")
            .font(.caption.weight(.bold))
            .tracking(1.0)
            .foregroundStyle(color)
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(color, lineWidth: 1)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Warning. \(text)")
    .accessibilityIdentifier("rigging.amber")
}

private func cardStroke(_ panel: SlingingRiggingModel.Panel) -> some View {
    let color = strokeColor(panel)
    return RoundedRectangle(cornerRadius: 22, style: .continuous)
        .strokeBorder(color ?? .clear, lineWidth: color == nil ? 0 : 1.5)
}

private func strokeColor(_ panel: SlingingRiggingModel.Panel) -> Color? {
    switch panel {
    case .blocked:
        return AppTheme.danger
    case .sling(let row):
        return row.amber == nil ? nil : AppTheme.gold
    case .chainSingle(let row):
        return row.amber == nil ? nil : AppTheme.gold
    case .chainPair:
        return AppTheme.gold
    case .guidance, .invalid:
        return nil
    }
}
