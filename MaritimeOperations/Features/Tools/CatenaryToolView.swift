import SwiftUI

struct CatenaryToolView: View {
    @State private var hText = ""
    @State private var wText = ""
    @State private var sText = ""
    @State private var depthText = ""

    private enum Field: Hashable { case h, w, s, depth }

    private var outcome: CatenaryMath.Outcome? {
        // Incomplete → dash (nil), not invalid.
        guard let H = ToolsParse.double(hText),
              let w = ToolsParse.double(wText),
              let S = ToolsParse.double(sText) else { return nil }

        let depthTrim = depthText.trimmingCharacters(in: .whitespacesAndNewlines)
        let depth: Double?
        if depthTrim.isEmpty {
            depth = nil
        } else if let d = ToolsParse.double(depthText) {
            depth = d
        } else {
            return .invalid(reason: "Depth must be finite and > 0 when provided.")
        }

        return CatenaryMath.freeHang(H: H, w: w, S: S, depth: depth)
    }

    /// Parsed optional depth when the field is non-empty and valid; nil if empty or incomplete inputs.
    private var parsedDepth: Double? {
        let depthTrim = depthText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !depthTrim.isEmpty else { return nil }
        return ToolsParse.double(depthText)
    }

    private var okResult: CatenaryMath.Result? {
        if case .ok(let r)? = outcome { return r }
        return nil
    }

    private var fieldError: (Field, String)? {
        guard case .invalid(let reason)? = outcome else { return nil }
        let lower = reason.lowercased()
        if lower.contains("depth") { return (.depth, reason) }
        if lower.contains("h,") || lower.hasPrefix("h ") { return (.h, reason) }
        // Generic gate covers H/w/S together — tint all required if invalid with incomplete-looking inputs already filtered.
        return (.h, reason)
    }

    var body: some View {
        ZStack {
            AppCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Tow Curve card above Inputs (Pixel mock3)
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionCaption("TOW CURVE")
                            Text("Bollard pull catenary")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            CatenaryTowCurveDiagram(
                                result: okResult,
                                depthMeters: (okResult != nil) ? parsedDepth : nil
                            )
                            resultsBlock
                            seabedStatusPill
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionCaption("INPUTS")
                            ToolNumberField(
                                title: "Horizontal tension H",
                                text: $hText,
                                placeholder: "106",
                                unit: "t",
                                isError: fieldError?.0 == .h,
                                errorReason: fieldError?.0 == .h ? fieldError?.1 : nil
                            )
                            ToolNumberField(
                                title: "Linear density w",
                                text: $wText,
                                placeholder: "108",
                                unit: "kg/m",
                                isError: fieldError?.0 == .w,
                                errorReason: fieldError?.0 == .w ? fieldError?.1 : nil
                            )
                            ToolNumberField(
                                title: "Paid-out length S",
                                text: $sText,
                                placeholder: "1500",
                                unit: "m",
                                isError: fieldError?.0 == .s,
                                errorReason: fieldError?.0 == .s ? fieldError?.1 : nil
                            )
                            ToolNumberField(
                                title: "Depth (optional)",
                                text: $depthText,
                                placeholder: "—",
                                unit: "m",
                                isError: fieldError?.0 == .depth,
                                errorReason: fieldError?.0 == .depth ? fieldError?.1 : nil
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Catenary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolsKeyboardDone()
    }

    @ViewBuilder
    private var resultsBlock: some View {
        switch outcome {
        case nil:
            ToolResultHero(caption: "Horizontal distance", value: ToolsParse.dash, unit: "m")
            ToolResultRow(title: "Sag", value: "\(ToolsParse.dash) m")
        case .invalid(let reason):
            ToolResultHero(caption: "Horizontal distance", value: ToolsParse.dash, unit: "m")
            Text(reason)
                .font(.footnote)
                .foregroundStyle(AppTheme.danger)
        case .ok(let r):
            ToolResultHero(
                caption: "Horizontal distance",
                value: ToolsParse.format(r.spanL, decimals: 1),
                unit: "m"
            )
            ToolResultRow(title: "Sag", value: "\(ToolsParse.format(r.sag, decimals: 1)) m")
        }
    }

    @ViewBuilder
    private var seabedStatusPill: some View {
        if case .ok(let r) = outcome, let clearance = r.clearance {
            if r.seabedWarning {
                ToolWarningPill(text: "Wire on seabed")
            } else {
                ToolClearPill(text: "Clear of seabed by \(ToolsParse.format(clearance, decimals: 0)) m")
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
