import SwiftUI

/// Tools list identity. Raw values match `toolTile.*` and `ToolLastResultKind`.
enum DeckTool: String, CaseIterable, Identifiable, Hashable {
    case gyro
    case catenary
    case winch
    case chainLocker
    case craneHeel
    case rigging
    case portUnlocode

    var id: String { rawValue }

    /// Regular-width Tools opens on Winch capacity.
    static let splitDefault: DeckTool = .winch

    /// Right pane of the one Tools split. Fills that pane. Does not open another split.
    @ViewBuilder
    var detail: some View {
        screen
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var screen: some View {
        switch self {
        case .catenary: CatenaryToolView()
        case .winch: WinchCapacityToolView()
        case .gyro: GyroCompassToolView()
        case .chainLocker: ChainLockerToolView()
        case .craneHeel: CraneHeelView()
        case .rigging: SlingingRiggingToolView()
        case .portUnlocode: PortUnlocodeToolView()
        }
    }
}
