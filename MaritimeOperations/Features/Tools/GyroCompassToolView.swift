import SwiftUI

/// Copy shared by the Gyro & Compass screen and its tests.
enum GyroCompassCopy {
    static let title = "Gyro & Compass"
    static let footer = "Aid, not authority."
    static let liveNote = "Updates as you type — no Calculate button."
    static let rowHint = "Gyro check and sun-amplitude compass error"
    static let polarBody = "Sun doesn't rise or set here"
    static let polarHelper = "|lat| + |dec| ≥ 90° (including exactly 90°). Try a lower latitude or another day. No numbers shown."
    static let compassSubtitle = "Sun amplitude · declination ≤ 23°30′"
    static let compassNote = "Theoretical rise or set (sun's centre on the celestial horizon). For a visible-horizon observation, the usual correction still applies."
    static let deviationNote = "Deviation = error − variation. Error is East when true > compass."
    static let compassEmpty = "Enter latitude, declination and compass bearing"
    static let gyroEmpty = "Enter all fields to see the true bearing and gyro error."
}

/// One Tools screen: Gyro check and sun-amplitude compass error, sharing latitude and declination.
struct GyroCompassToolView: View {
    enum Tab: String, CaseIterable, Identifiable, Hashable {
        case gyro = "Gyro"
        case compass = "Compass"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .gyro
    @State private var gyroModel: GyroCheckModel
    @State private var compassModel: CompassErrorModel
    private let store = ToolLastResultStore()

    init() {
        let position = LatDecDraft()
        _gyroModel = State(initialValue: GyroCheckModel(position: position))
        _compassModel = State(initialValue: CompassErrorModel(position: position))
    }

    var body: some View {
        ZStack {
            AppCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ToolSegmentBar(
                        title: "Gyro or Compass",
                        barIdentifier: "gyroCompass.switch",
                        selection: $tab,
                        options: Tab.allCases.map { item in
                            ToolSegmentOption(
                                value: item,
                                title: item.rawValue,
                                accessibilityLabel: item.rawValue,
                                accessibilityIdentifier: "gyroCompass.tab.\(item.rawValue)"
                            )
                        }
                    )
                    switch tab {
                    case .gyro:
                        GyroCheckToolView(model: gyroModel)
                    case .compass:
                        CompassErrorToolView(model: compassModel)
                    }
                    Text(GyroCompassCopy.footer)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("gyroCompass.footer")
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(GyroCompassCopy.title)
        .navigationBarTitleDisplayMode(.inline)
        .systemGlassNavigation()
        .toolsKeyboardDone()
        .onDisappear {
            let summary = ToolLastResultStore.summaryToSave(
                tab: tab == .gyro ? .gyro : .compass,
                gyro: gyroModel.lastResultSummary(),
                compass: compassModel.lastResultSummary
            )
            if let summary { store.save(summary, for: .gyro) }
        }
    }
}

/// Latitude and declination rows bound to the shared draft.
struct SharedLatDecFields: View {
    @Bindable var position: LatDecDraft
    var declinationMax: Double
    var latitudeIdentifier: String
    var declinationIdentifier: String
    var latitudeError: String?
    var declinationError: String?

    var body: some View {
        ToolDegMinInput(
            title: "Latitude",
            degrees: $position.latDeg,
            minutes: $position.latMin,
            hemisphere: $position.latNS,
            hemispheres: [(.n, "N"), (.s, "S")],
            hemisphereLabel: "Latitude hemisphere",
            echo: CompassErrorModel.echo(
                degrees: position.latDeg, minutes: position.latMin,
                hemisphere: position.latNS.rawValue, maxDegrees: 90
            ),
            errorReason: latitudeError,
            identifier: latitudeIdentifier,
            systemImage: "location",
            hemisphereAccessibility: ["North", "South"]
        )
        ToolDegMinInput(
            title: "Declination",
            degrees: $position.decDeg,
            minutes: $position.decMin,
            hemisphere: $position.decNS,
            hemispheres: [(.n, "N"), (.s, "S")],
            hemisphereLabel: "Declination name",
            echo: CompassErrorModel.echo(
                degrees: position.decDeg, minutes: position.decMin,
                hemisphere: position.decNS.rawValue, maxDegrees: declinationMax
            ),
            errorReason: declinationError,
            identifier: declinationIdentifier,
            systemImage: "sun.max",
            hemisphereAccessibility: ["North", "South"]
        )
    }
}
