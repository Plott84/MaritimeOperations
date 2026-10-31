import SwiftUI

/// Size-class shell for a regular iPhone and iPhone Duo.
///
/// Split when the horizontal size class is regular (Duo inner, wide window).
/// Compact horizontal stays the Soft C column: iPhone, Duo outer portrait, and
/// compact×compact landscape. Vertical size class is an input so a regular
/// vertical size on its own never opens the split.
///
/// Deployment is iOS 26.2. `ArrangementView` and the Duo right-edge tab strip
/// need the iOS 27.1 SDK, so this pass does not use them and does not raise
/// the deployment target. Home and Export use a size-class column split.
/// Tools and Entries use `NavigationSplitView`. Tabs stay the Soft C bottom
/// bar (Main · Entries · Tools · Export) at every size class. The tab title
/// is Entries, never Log.
///
/// Layout does not read device names, idiom, orientation, or `UIScreen.main`,
/// and it does not compare the scene to an inferred Duo canvas size.
enum DuoAxisClass: Equatable {
    case compact
    case regular
    case unspecified
}

extension DuoAxisClass {
    init(_ sizeClass: UserInterfaceSizeClass?) {
        switch sizeClass {
        case .regular: self = .regular
        case .compact: self = .compact
        default: self = .unspecified
        }
    }
}

enum DuoSizeClass {
    /// Regular horizontal width splits. Compact horizontal stays one column, including
    /// compact×regular (phone and Duo outer portrait) and compact×compact landscape.
    /// Callers pass both traits. Height alone never opens the split.
    static func usesSplit(horizontal: DuoAxisClass, vertical _: DuoAxisClass) -> Bool {
        horizontal == .regular
    }
}

/// Preferred sidebar for Tools and Entries. A flexible column width, not a Duo canvas size.
enum DuoSidebar {
    static let min: CGFloat = 300
    static let ideal: CGFloat = 320
    static let max: CGFloat = 340
}

/// Preferred Tools sidebar. A flexible column width, not a Duo canvas size.
enum DuoToolsColumn {
    static let emptyDetail = "Select a tool"
    static let defaultToolID = DeckTool.splitDefault.rawValue
    static let sidebarMin: CGFloat = DuoSidebar.min
    static let sidebarIdeal: CGFloat = DuoSidebar.ideal
    static let sidebarMax: CGFloat = DuoSidebar.max
}

/// Regular Entries: books sidebar and the selected book’s list. Default is DP
/// when that book is in the list, otherwise the primary starred book, otherwise the first.
enum DuoEntriesColumn {
    static let emptyDetail = "Select a book"
    static let sidebarMin: CGFloat = DuoSidebar.min
    static let sidebarIdeal: CGFloat = DuoSidebar.ideal
    static let sidebarMax: CGFloat = DuoSidebar.max

    static func defaultSelection(available: [LogBook], primary: HomeBook) -> LogBook? {
        if available.contains(.dp) { return .dp }
        let starred = primary.logBook
        if available.contains(starred) { return starred }
        return available.first
    }
}

/// Export regions. Compact is one column. Regular puts controls on the left
/// and the preview, disclaimer, and Share strip on the right.
enum DuoExportRegion: Equatable {
    case books
    case dateRange
    case preview
    case disclaimer
    case share
}

enum DuoExportLayout {
    static func columns(split: Bool) -> (left: [DuoExportRegion], right: [DuoExportRegion]) {
        if split {
            return ([.books, .dateRange], [.preview, .disclaimer, .share])
        }
        return ([.books, .dateRange, .preview, .disclaimer, .share], [])
    }
}

/// Which Home regions each size class shows. The DP hero is the primary block
/// when DP is on Main (timer, idle prefill, DP days). Another primary book
/// keeps that book's hero on the left. The secondary book is the existing
/// compact card, never a second hero.
enum DuoHomeRegion: Equatable {
    case onMainChip
    case primaryHero
    case yourBooks
    case secondaryCard
    case latestActivity
}

enum DuoHomeLayout {
    static func onMainBooks(_ books: HomeBooks) -> [HomeBook] {
        if let secondary = books.secondary {
            return [books.primary, secondary]
        }
        return [books.primary]
    }

    static func columns(split: Bool, hasSecondary: Bool) -> (left: [DuoHomeRegion], right: [DuoHomeRegion]) {
        if split {
            var right: [DuoHomeRegion] = [.yourBooks, .latestActivity]
            if hasSecondary {
                right.insert(.secondaryCard, at: 1)
            }
            return ([.primaryHero], right)
        }
        var column: [DuoHomeRegion] = [.onMainChip, .primaryHero, .latestActivity]
        if hasSecondary {
            column.insert(.secondaryCard, at: 2)
        }
        return (column, [])
    }
}

/// Reads both size classes and reports whether Home, Tools, Entries, and Export should split.
struct DuoSizeClassReader<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @ViewBuilder var content: (Bool) -> Content

    private var split: Bool {
        DuoSizeClass.usesSplit(
            horizontal: DuoAxisClass(horizontalSizeClass),
            vertical: DuoAxisClass(verticalSizeClass)
        )
    }

    var body: some View {
        content(split)
    }
}
