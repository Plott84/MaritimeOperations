import Foundation

/// Pixel copy for the Import sheet. The read-error apostrophe is U+2019, matching the spec.
enum ImportCopy {
    static let inlineError = "Couldn\u{2019}t read this file"
    static let emptyPreview = "Choose a file to preview books and entry counts."
    static let mergeHelper = "Adds entries from the file. Exact duplicates are skipped."
    static let replaceWarning = "Replace will overwrite books that are in this file. Other books are left alone."
    static let chosenVia = "Chosen via Files \u{00B7} AirDrop \u{00B7} Share sheet"
    static let capsNote = "PDF or CSV from Export. Caps: Files \u{00B7} AirDrop \u{00B7} Share sheet."
    static let importButton = "Import\u{2026}"
    static let replaceAlertTitle = "Replace books?"
    static let replaceAlertButton = "Replace"
}

enum ImportReadError: Error, Equatable {
    case unsupportedType
    case notMaritimeExport
    /// Totals-only Export from before entry records existed. Not safe to apply.
    case legacySummaryOnly
    case countMismatch
    case duplicateIdentity

    var inlineMessage: String { ImportCopy.inlineError }
}

enum ImportMode: String, Equatable, CaseIterable, Identifiable {
    case merge
    case replaceBooks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .merge: return "Merge"
        case .replaceBooks: return "Replace books"
        }
    }
}

// MARK: - Records

/// Transfer records for one export file.
/// `id` is the only uniqueness field on DPEntry, RigMove, ROVEntry, and CraneEntry.
struct DPRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var sourceRaw: String
    var date: Date
    var startTime: Date?
    var endTime: Date?
    var durationHours: Double
    var vessel: String
    var rig: String
    var vesselType: String
    var dpClass: String
    var mode: String?
    var activityCode: String?
    var notes: String?
    var masterInitials: String?
    var locationName: String
    var client: String
    var locationFromPhone: Bool
    var latitudeText: String
    var longitudeText: String
    var dpClassLevel: Int?
    var rank: String?
    var createdAt: Date
    var updatedAt: Date
}

struct RigMoveRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var rigName: String
    var date: Date
    var startTime: Date?
    var endTime: Date?
    var operationRaw: String
    var notes: String
    var isDone: Bool
    var createdAt: Date
    var client: String
    var fromLocation: String
    var toLocation: String
    var vessel: String
    var rank: String
    var projectText: String
    var anchorLineCount: Int
    var hasChain: Bool
    var hasWire: Bool
    var hasFiber: Bool
    var hasSubBuoys: Bool
    var hasOther: Bool
    var otherEquipment: String
    var ahJobTypeRaw: String?
    var ahUnderTraining: Bool?
    var ahUnitTypeRaw: String?
    var ahFieldArea: String?
    var ahTasksRaw: String?
    var ahControlModeRaw: String?
    var ahSupervised: Bool?
    var ahAnchorIDs: String?
    var ahWaterDepthM: Double?
    var ahMaxPaidOutM: Double?
    var ahPeakTensionT: Double?
    var ahWaveHeightM: Double?
    var ahWindKn: Double?
    var ahWindDirection: String?

    /// Same hours Export adds into the anchor-handling hours column. Not DP hours.
    var workedHours: Double? {
        guard let startTime, let endTime else { return nil }
        return RigMoveCheck.workedHours(start: startTime, finish: endTime)
    }
}

struct ROVRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var date: Date
    var endTime: Date?
    var vessel: String?
    var gradeRaw: String?
    var gradeOther: String?
    var underTraining: Bool?
    var rovSystem: String?
    var rovClassRaw: String?
    var fieldArea: String?
    var jobTypeRaw: String?
    var tasksRaw: String?
    var pilotingHours: Double?
    var dives: Int?
    var supportSiteRaw: String?
    var supportSiteOther: String?
    var remarks: String?
    var createdAt: Date
    var updatedAt: Date
}

struct CraneRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var date: Date
    var endTime: Date?
    var vessel: String?
    var rank: String?
    var underTraining: Bool?
    var craneName: String?
    var craneTypeRaw: String?
    var craneTypeOther: String?
    var fieldArea: String?
    var hoursOperated: Double?
    var liftTypesRaw: String?
    var dayNightRaw: String?
    var windMS: Double?
    var waveHeightM: Double?
    var craneModeRaw: String?
    var remarks: String?
    var createdAt: Date
    var updatedAt: Date
}

struct ImportPayload: Equatable {
    /// Books named in the export summary, including a selected book with zero rows.
    var booksPresent: [LogBook]
    var dp: [DPRecord]
    var moves: [RigMoveRecord]
    var rov: [ROVRecord]
    var crane: [CraneRecord]

    var recordCount: Int { dp.count + moves.count + rov.count + crane.count }

    /// DP hours are the sum of DP records only. ROV and Crane stay on their own books.
    func exportSnapshot() -> ExportSnapshot {
        ExportSnapshot(
            dpEntries: dp.count,
            dpHours: dp.reduce(0) { $0 + $1.durationHours },
            rigMoves: moves.count,
            anchorHours: moves.reduce(0) { $0 + ($1.workedHours ?? 0) },
            rovEntries: rov.count,
            rovHours: rov.reduce(0) { $0 + ($1.pilotingHours ?? 0) },
            craneEntries: crane.count,
            craneHours: crane.reduce(0) { $0 + ($1.hoursOperated ?? 0) }
        )
    }

    func previewLines() -> [String] {
        let snapshot = exportSnapshot()
        var selection = ExportBookSelection(dp: false, anchorHandling: false, rov: false, crane: false)
        for book in booksPresent {
            selection.set(book, on: true)
        }
        return snapshot.previewLines(for: selection)
    }
}

struct ImportLibrary: Equatable {
    var dp: [DPRecord] = []
    var moves: [RigMoveRecord] = []
    var rov: [ROVRecord] = []
    var crane: [CraneRecord] = []

    func applying(_ plan: ImportPlan) -> ImportLibrary {
        var next = self
        next.dp.removeAll { plan.deleteDP.contains($0.id) }
        next.dp.append(contentsOf: plan.insertDP)
        next.moves.removeAll { plan.deleteMoves.contains($0.id) }
        next.moves.append(contentsOf: plan.insertMoves)
        next.rov.removeAll { plan.deleteROV.contains($0.id) }
        next.rov.append(contentsOf: plan.insertROV)
        next.crane.removeAll { plan.deleteCrane.contains($0.id) }
        next.crane.append(contentsOf: plan.insertCrane)
        return next
    }
}

struct ImportReport: Equatable {
    var added: Int
    var skippedDuplicates: Int
    var booksChanged: [LogBook]
    var mode: ImportMode

    /// One changed book opens that book. Several changed books, or none, stay on the Log list.
    var logPath: [LogBook] {
        booksChanged.count == 1 ? booksChanged : []
    }

    var toastText: String {
        switch mode {
        case .merge:
            let addedText = added == 1 ? "Added 1 entry" : "Added \(added) entries"
            guard skippedDuplicates > 0 else { return "\(addedText)." }
            let skippedText = skippedDuplicates == 1 ? "Skipped 1 duplicate" : "Skipped \(skippedDuplicates) duplicates"
            return "\(addedText). \(skippedText)."
        case .replaceBooks:
            let entryText = added == 1 ? "1 entry" : "\(added) entries"
            let names = booksChanged.map(\.title)
            guard !names.isEmpty else { return "Replaced 0 books. \(entryText)." }
            return "Replaced \(names.joined(separator: ", ")). \(entryText)."
        }
    }
}

struct ImportPlan: Equatable {
    var mode: ImportMode
    var deleteDP: Set<UUID> = []
    var deleteMoves: Set<UUID> = []
    var deleteROV: Set<UUID> = []
    var deleteCrane: Set<UUID> = []
    var insertDP: [DPRecord] = []
    var insertMoves: [RigMoveRecord] = []
    var insertROV: [ROVRecord] = []
    var insertCrane: [CraneRecord] = []
    var report: ImportReport
}

/// Merge skips a row when that book already has the same `id`.
/// Replace deletes and rewrites only `booksPresent`. Other books are not in the plan.
enum ImportPlanner {
    static func plan(mode: ImportMode, existing: ImportLibrary, payload: ImportPayload) -> ImportPlan {
        switch mode {
        case .merge:
            return merge(existing: existing, payload: payload)
        case .replaceBooks:
            return replace(existing: existing, payload: payload)
        }
    }

    private static func merge(existing: ImportLibrary, payload: ImportPayload) -> ImportPlan {
        let insertDP = payload.dp.filter { id in !existing.dp.contains { $0.id == id.id } }
        let insertMoves = payload.moves.filter { id in !existing.moves.contains { $0.id == id.id } }
        let insertROV = payload.rov.filter { id in !existing.rov.contains { $0.id == id.id } }
        let insertCrane = payload.crane.filter { id in !existing.crane.contains { $0.id == id.id } }
        let added = insertDP.count + insertMoves.count + insertROV.count + insertCrane.count
        var changed: [LogBook] = []
        if !insertDP.isEmpty { changed.append(.dp) }
        if !insertMoves.isEmpty { changed.append(.anchorHandling) }
        if !insertROV.isEmpty { changed.append(.rov) }
        if !insertCrane.isEmpty { changed.append(.crane) }
        return ImportPlan(
            mode: .merge,
            insertDP: insertDP,
            insertMoves: insertMoves,
            insertROV: insertROV,
            insertCrane: insertCrane,
            report: ImportReport(
                added: added,
                skippedDuplicates: payload.recordCount - added,
                booksChanged: changed,
                mode: .merge
            )
        )
    }

    private static func replace(existing: ImportLibrary, payload: ImportPayload) -> ImportPlan {
        let present = Set(payload.booksPresent)
        var plan = ImportPlan(
            mode: .replaceBooks,
            report: ImportReport(added: 0, skippedDuplicates: 0, booksChanged: payload.booksPresent, mode: .replaceBooks)
        )
        if present.contains(.dp) {
            plan.deleteDP = Set(existing.dp.map(\.id))
            plan.insertDP = payload.dp
        }
        if present.contains(.anchorHandling) {
            plan.deleteMoves = Set(existing.moves.map(\.id))
            plan.insertMoves = payload.moves
        }
        if present.contains(.rov) {
            plan.deleteROV = Set(existing.rov.map(\.id))
            plan.insertROV = payload.rov
        }
        if present.contains(.crane) {
            plan.deleteCrane = Set(existing.crane.map(\.id))
            plan.insertCrane = payload.crane
        }
        plan.report.added = plan.insertDP.count + plan.insertMoves.count + plan.insertROV.count + plan.insertCrane.count
        return plan
    }
}

// MARK: - Model mapping

extension DPRecord {
    init(_ entry: DPEntry) {
        id = entry.id
        sourceRaw = entry.sourceRaw
        date = entry.date
        startTime = entry.startTime
        endTime = entry.endTime
        durationHours = entry.durationHours
        vessel = entry.vessel
        rig = entry.rig
        vesselType = entry.vesselType
        dpClass = entry.dpClass
        mode = entry.mode
        activityCode = entry.activityCode
        notes = entry.notes
        masterInitials = entry.masterInitials
        locationName = entry.locationName
        client = entry.client
        locationFromPhone = entry.locationFromPhone
        latitudeText = entry.latitudeText
        longitudeText = entry.longitudeText
        dpClassLevel = entry.dpClassLevel
        rank = entry.rank
        createdAt = entry.createdAt
        updatedAt = entry.updatedAt
    }

    func makeModel() -> DPEntry {
        let entry = DPEntry(
            id: id,
            source: DPEntrySource(rawValue: sourceRaw) ?? .manual,
            date: date,
            startTime: startTime,
            endTime: endTime,
            durationHours: durationHours,
            vessel: vessel,
            rig: rig,
            vesselType: vesselType,
            dpClass: dpClass,
            mode: mode,
            activityCode: activityCode,
            notes: notes,
            masterInitials: masterInitials,
            locationName: locationName,
            client: client,
            locationFromPhone: locationFromPhone,
            latitudeText: latitudeText,
            longitudeText: longitudeText,
            dpClassLevel: dpClassLevel,
            rank: rank,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        entry.sourceRaw = sourceRaw
        return entry
    }
}

extension RigMoveRecord {
    init(_ move: RigMove) {
        id = move.id
        rigName = move.rigName
        date = move.date
        startTime = move.startTime
        endTime = move.endTime
        operationRaw = move.operationRaw
        notes = move.notes
        isDone = move.isDone
        createdAt = move.createdAt
        client = move.client
        fromLocation = move.fromLocation
        toLocation = move.toLocation
        vessel = move.vessel
        rank = move.rank
        projectText = move.projectText
        anchorLineCount = move.anchorLineCount
        hasChain = move.hasChain
        hasWire = move.hasWire
        hasFiber = move.hasFiber
        hasSubBuoys = move.hasSubBuoys
        hasOther = move.hasOther
        otherEquipment = move.otherEquipment
        ahJobTypeRaw = move.ahJobTypeRaw
        ahUnderTraining = move.ahUnderTraining
        ahUnitTypeRaw = move.ahUnitTypeRaw
        ahFieldArea = move.ahFieldArea
        ahTasksRaw = move.ahTasksRaw
        ahControlModeRaw = move.ahControlModeRaw
        ahSupervised = move.ahSupervised
        ahAnchorIDs = move.ahAnchorIDs
        ahWaterDepthM = move.ahWaterDepthM
        ahMaxPaidOutM = move.ahMaxPaidOutM
        ahPeakTensionT = move.ahPeakTensionT
        ahWaveHeightM = move.ahWaveHeightM
        ahWindKn = move.ahWindKn
        ahWindDirection = move.ahWindDirection
    }

    func makeModel() -> RigMove {
        let move = RigMove(
            id: id,
            rigName: rigName,
            date: date,
            startTime: startTime,
            endTime: endTime,
            operation: RigMoveOperation(rawValue: operationRaw) ?? .anchorHandling,
            notes: notes,
            isDone: isDone,
            createdAt: createdAt,
            client: client,
            fromLocation: fromLocation,
            toLocation: toLocation,
            vessel: vessel,
            rank: rank,
            projectText: projectText,
            anchorLineCount: anchorLineCount,
            hasChain: hasChain,
            hasWire: hasWire,
            hasFiber: hasFiber,
            hasSubBuoys: hasSubBuoys,
            hasOther: hasOther,
            otherEquipment: otherEquipment
        )
        move.operationRaw = operationRaw
        move.ahJobTypeRaw = ahJobTypeRaw
        move.ahUnderTraining = ahUnderTraining
        move.ahUnitTypeRaw = ahUnitTypeRaw
        move.ahFieldArea = ahFieldArea
        move.ahTasksRaw = ahTasksRaw
        move.ahControlModeRaw = ahControlModeRaw
        move.ahSupervised = ahSupervised
        move.ahAnchorIDs = ahAnchorIDs
        move.ahWaterDepthM = ahWaterDepthM
        move.ahMaxPaidOutM = ahMaxPaidOutM
        move.ahPeakTensionT = ahPeakTensionT
        move.ahWaveHeightM = ahWaveHeightM
        move.ahWindKn = ahWindKn
        move.ahWindDirection = ahWindDirection
        return move
    }
}

extension ROVRecord {
    init(_ entry: ROVEntry) {
        id = entry.id
        date = entry.date
        endTime = entry.endTime
        vessel = entry.vessel
        gradeRaw = entry.gradeRaw
        gradeOther = entry.gradeOther
        underTraining = entry.underTraining
        rovSystem = entry.rovSystem
        rovClassRaw = entry.rovClassRaw
        fieldArea = entry.fieldArea
        jobTypeRaw = entry.jobTypeRaw
        tasksRaw = entry.tasksRaw
        pilotingHours = entry.pilotingHours
        dives = entry.dives
        supportSiteRaw = entry.supportSiteRaw
        supportSiteOther = entry.supportSiteOther
        remarks = entry.remarks
        createdAt = entry.createdAt
        updatedAt = entry.updatedAt
    }

    func makeModel() -> ROVEntry {
        let entry = ROVEntry(id: id, date: date, endTime: endTime, vessel: vessel, createdAt: createdAt)
        entry.gradeRaw = gradeRaw
        entry.gradeOther = gradeOther
        entry.underTraining = underTraining
        entry.rovSystem = rovSystem
        entry.rovClassRaw = rovClassRaw
        entry.fieldArea = fieldArea
        entry.jobTypeRaw = jobTypeRaw
        entry.tasksRaw = tasksRaw
        entry.pilotingHours = pilotingHours
        entry.dives = dives
        entry.supportSiteRaw = supportSiteRaw
        entry.supportSiteOther = supportSiteOther
        entry.remarks = remarks
        entry.updatedAt = updatedAt
        return entry
    }
}

extension CraneRecord {
    init(_ entry: CraneEntry) {
        id = entry.id
        date = entry.date
        endTime = entry.endTime
        vessel = entry.vessel
        rank = entry.rank
        underTraining = entry.underTraining
        craneName = entry.craneName
        craneTypeRaw = entry.craneTypeRaw
        craneTypeOther = entry.craneTypeOther
        fieldArea = entry.fieldArea
        hoursOperated = entry.hoursOperated
        liftTypesRaw = entry.liftTypesRaw
        dayNightRaw = entry.dayNightRaw
        windMS = entry.windMS
        waveHeightM = entry.waveHeightM
        craneModeRaw = entry.craneModeRaw
        remarks = entry.remarks
        createdAt = entry.createdAt
        updatedAt = entry.updatedAt
    }

    func makeModel() -> CraneEntry {
        let entry = CraneEntry(id: id, date: date, endTime: endTime, vessel: vessel, createdAt: createdAt)
        entry.rank = rank
        entry.underTraining = underTraining
        entry.craneName = craneName
        entry.craneTypeRaw = craneTypeRaw
        entry.craneTypeOther = craneTypeOther
        entry.fieldArea = fieldArea
        entry.hoursOperated = hoursOperated
        entry.liftTypesRaw = liftTypesRaw
        entry.dayNightRaw = dayNightRaw
        entry.windMS = windMS
        entry.waveHeightM = waveHeightM
        entry.craneModeRaw = craneModeRaw
        entry.remarks = remarks
        entry.updatedAt = updatedAt
        return entry
    }
}

// MARK: - CSV / PDF payload

enum ImportJSON {
    static func string<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.timeIntervalSince1970)
        }
        let data = try encoder.encode(value)
        guard let text = String(data: data, encoding: .utf8) else {
            throw ImportReadError.notMaritimeExport
        }
        return text
    }

    static func value<T: Decodable>(_ json: String, as type: T.Type) throws -> T {
        guard let data = json.data(using: .utf8) else { throw ImportReadError.notMaritimeExport }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let seconds = try container.decode(Double.self)
            return Date(timeIntervalSince1970: seconds)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw ImportReadError.notMaritimeExport
        }
    }
}

/// Export CSV plus the entry records Import can apply.
/// The summary block stays the totals table Export already wrote.
/// `section,records,1` then one `entry` row per log line.
///
/// PDF desk cards are drawn pages and do not contain those rows. After the PDF bytes,
/// Export appends one comment line `%MARITIMEOPSEXPORTV1 <base64 csv>`. Readers stop at
/// `%%EOF`, so the page is unchanged. A PDF without that trailer cannot be imported.
enum ImportExchange {
    static let recordsVersion = 1
    static let pdfTrailerMarker = "%MARITIMEOPSEXPORTV1 "

    static func encodeCSV(
        books: ExportBookSelection,
        filter: ExportDateFilter,
        dp: [DPEntry],
        moves: [RigMove],
        rov: [ROVEntry],
        crane: [CraneEntry],
        calendar: Calendar = .current
    ) throws -> String {
        let dpRows = books.dp ? dp.filter { filter.contains($0.date, calendar: calendar) } : []
        let moveRows = books.anchorHandling ? moves.filter { filter.contains($0.date, calendar: calendar) } : []
        let rovRows = books.rov ? rov.filter { filter.contains($0.date, calendar: calendar) } : []
        let craneRows = books.crane ? crane.filter { filter.contains($0.date, calendar: calendar) } : []
        let snapshot = ExportAggregator.snapshot(
            dp: dpRows,
            moves: moveRows,
            rov: rovRows,
            crane: craneRows,
            filter: ExportDateFilter(quickRange: .allTime, from: nil, to: nil),
            calendar: calendar
        )

        var rows: [String] = []
        rows.append("book,count,hours,notes")
        for book in books.selectedBooks {
            let count = snapshot.count(for: book)
            let hours: String
            if book == .anchorHandling {
                hours = String(format: "%.1f", snapshot.anchorHours)
            } else if let value = snapshot.hours(for: book) {
                hours = String(format: "%.1f", value)
            } else {
                hours = "0.0"
            }
            let note: String
            switch book {
            case .dp: note = "DP book only; ROV/Crane excluded"
            case .anchorHandling: note = "count is rig moves"
            case .rov: note = "piloting hours"
            case .crane: note = "hours operated"
            }
            rows.append("\"\(book.title)\",\(count),\(hours),\"\(note)\"")
        }
        rows.append("")
        rows.append("period,\"\(periodCSV(filter))\"")
        rows.append("disclaimer,\"\(ExportDisclaimer.text)\"")
        rows.append("rule,\"\(ExportDisclaimer.previewFooter)\"")
        rows.append("section,records,\(recordsVersion)")
        for entry in dpRows {
            rows.append(try entryRow(book: .dp, id: entry.id, json: try ImportJSON.string(DPRecord(entry))))
        }
        for move in moveRows {
            rows.append(try entryRow(book: .anchorHandling, id: move.id, json: try ImportJSON.string(RigMoveRecord(move))))
        }
        for entry in rovRows {
            rows.append(try entryRow(book: .rov, id: entry.id, json: try ImportJSON.string(ROVRecord(entry))))
        }
        for entry in craneRows {
            rows.append(try entryRow(book: .crane, id: entry.id, json: try ImportJSON.string(CraneRecord(entry))))
        }
        return rows.joined(separator: "\n") + "\n"
    }

    static func embedCSV(_ csv: String, in pdf: Data) -> Data {
        var out = pdf
        if let last = pdf.last, last != 0x0A {
            out.append(0x0A)
        }
        let encoded = Data(csv.utf8).base64EncodedString()
        out.append(Data("\(pdfTrailerMarker)\(encoded)\n".utf8))
        return out
    }

    static func extractEmbeddedCSV(from data: Data) -> String? {
        guard let latin = String(data: data, encoding: .isoLatin1) else { return nil }
        guard let range = latin.range(of: pdfTrailerMarker, options: .backwards) else { return nil }
        let token = latin[range.upperBound...].prefix { $0 != "\n" && $0 != "\r" }
        guard !token.isEmpty, let decoded = Data(base64Encoded: String(token)) else { return nil }
        return String(data: decoded, encoding: .utf8)
    }

    static func parse(data: Data, filename: String) throws -> ImportPayload {
        switch fileExtension(filename) {
        case "csv":
            guard let text = String(data: data, encoding: .utf8) else {
                throw ImportReadError.notMaritimeExport
            }
            return try parseCSV(text)
        case "pdf":
            guard let csv = extractEmbeddedCSV(from: data) else {
                throw ImportReadError.notMaritimeExport
            }
            return try parseCSV(csv)
        default:
            throw ImportReadError.unsupportedType
        }
    }

    static func csvRows(_ text: String) throws -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var index = text.startIndex

        func finishField() {
            row.append(field)
            field = ""
        }

        func finishRow() {
            finishField()
            if !(row.count == 1 && row[0].isEmpty) {
                rows.append(row)
            }
            row = []
        }

        while index < text.endIndex {
            let character = text[index]
            if inQuotes {
                if character == "\"" {
                    let next = text.index(after: index)
                    if next < text.endIndex && text[next] == "\"" {
                        field.append("\"")
                        index = text.index(after: next)
                        continue
                    }
                    inQuotes = false
                    index = next
                    continue
                }
                field.append(character)
                index = text.index(after: index)
                continue
            }

            if character == "\"" && field.isEmpty {
                inQuotes = true
                index = text.index(after: index)
                continue
            }
            if character == "," {
                finishField()
                index = text.index(after: index)
                continue
            }
            if character == "\n" || character == "\r" {
                if character == "\r" {
                    let next = text.index(after: index)
                    if next < text.endIndex && text[next] == "\n" {
                        index = next
                    }
                }
                finishRow()
                index = text.index(after: index)
                continue
            }
            field.append(character)
            index = text.index(after: index)
        }

        if inQuotes { throw ImportReadError.notMaritimeExport }
        if !field.isEmpty || !row.isEmpty {
            finishRow()
        }
        return rows
    }

    static func parseCSV(_ text: String) throws -> ImportPayload {
        let rows = try csvRows(stripBOM(text))
        var summaries: [LogBook: Int] = [:]
        var disclaimerMatches = false
        var sawDisclaimer = false
        var sawRecords = false
        var version: Int?
        var dp: [DPRecord] = []
        var moves: [RigMoveRecord] = []
        var rov: [ROVRecord] = []
        var crane: [CraneRecord] = []
        var seenIDs = Set<UUID>()

        for row in rows {
            guard let first = row.first else { continue }
            if first == "book" || first == "period" || first == "rule" { continue }
            if first == "disclaimer" {
                sawDisclaimer = true
                disclaimerMatches = row.count >= 2 && row[1] == ExportDisclaimer.text
                continue
            }
            if first == "section" {
                if sawRecords { throw ImportReadError.notMaritimeExport }
                guard row.count >= 3, row[1] == "records", let parsed = Int(row[2]) else {
                    throw ImportReadError.notMaritimeExport
                }
                sawRecords = true
                version = parsed
                continue
            }
            if first == "entry" {
                guard sawRecords, version == recordsVersion else { throw ImportReadError.notMaritimeExport }
                guard row.count >= 4, let book = LogBook(rawValue: row[1]), let id = UUID(uuidString: row[2]) else {
                    throw ImportReadError.notMaritimeExport
                }
                if !seenIDs.insert(id).inserted { throw ImportReadError.duplicateIdentity }
                switch book {
                case .dp:
                    let record = try ImportJSON.value(row[3], as: DPRecord.self)
                    guard record.id == id else { throw ImportReadError.notMaritimeExport }
                    dp.append(record)
                case .anchorHandling:
                    let record = try ImportJSON.value(row[3], as: RigMoveRecord.self)
                    guard record.id == id else { throw ImportReadError.notMaritimeExport }
                    moves.append(record)
                case .rov:
                    let record = try ImportJSON.value(row[3], as: ROVRecord.self)
                    guard record.id == id else { throw ImportReadError.notMaritimeExport }
                    rov.append(record)
                case .crane:
                    let record = try ImportJSON.value(row[3], as: CraneRecord.self)
                    guard record.id == id else { throw ImportReadError.notMaritimeExport }
                    crane.append(record)
                }
                continue
            }
            if let book = LogBook.allCases.first(where: { $0.title == first }) {
                guard row.count >= 3, let count = Int(row[1]), summaries[book] == nil else {
                    throw ImportReadError.notMaritimeExport
                }
                summaries[book] = count
                continue
            }
            throw ImportReadError.notMaritimeExport
        }

        guard sawDisclaimer, disclaimerMatches else { throw ImportReadError.notMaritimeExport }
        guard sawRecords, let version else { throw ImportReadError.legacySummaryOnly }
        guard version == recordsVersion else { throw ImportReadError.notMaritimeExport }

        let counts: [LogBook: Int] = [
            .dp: dp.count,
            .anchorHandling: moves.count,
            .rov: rov.count,
            .crane: crane.count
        ]
        for (book, count) in counts where count > 0 && summaries[book] == nil {
            throw ImportReadError.countMismatch
        }
        for (book, summaryCount) in summaries where summaryCount != counts[book, default: 0] {
            throw ImportReadError.countMismatch
        }

        let present = LogBook.allCases.filter { summaries[$0] != nil }
        return ImportPayload(booksPresent: present, dp: dp, moves: moves, rov: rov, crane: crane)
    }

    private static func entryRow(book: LogBook, id: UUID, json: String) throws -> String {
        "entry,\(book.rawValue),\(id.uuidString),\(csvQuoted(json))"
    }

    private static func csvQuoted(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func periodCSV(_ filter: ExportDateFilter) -> String {
        if filter.isAllTime { return "All time" }
        let style = Date.FormatStyle(date: .abbreviated, time: .omitted)
        let fromText = filter.from.map { $0.formatted(style) } ?? ""
        let toText = filter.to.map { $0.formatted(style) } ?? ""
        return "\(fromText) \u{2013} \(toText)"
    }

    private static func stripBOM(_ text: String) -> String {
        text.hasPrefix("\u{feff}") ? String(text.dropFirst()) : text
    }

    private static func fileExtension(_ filename: String) -> String {
        (filename as NSString).pathExtension.lowercased()
    }
}

// MARK: - Sheet state

struct ImportReadFile: Equatable, Identifiable {
    let id: UUID
    var name: String
    var data: Data

    init(id: UUID = UUID(), name: String, data: Data) {
        self.id = id
        self.name = name
        self.data = data
    }

    var byteCount: Int { data.count }
}

struct ImportSession: Equatable {
    enum Source: Equatable {
        case empty
        case valid(name: String, byteCount: Int, payload: ImportPayload)
        case invalid(name: String, byteCount: Int, message: String)
    }

    var source: Source = .empty
    var mode: ImportMode = .merge

    var canImport: Bool {
        if case .valid = source { return true }
        return false
    }

    var payload: ImportPayload? {
        if case .valid(_, _, let payload) = source { return payload }
        return nil
    }

    var inlineError: String? {
        if case .invalid(_, _, let message) = source { return message }
        return nil
    }

    var chosenName: String? {
        switch source {
        case .empty: return nil
        case .valid(let name, _, _), .invalid(let name, _, _): return name
        }
    }

    var chosenByteCount: Int? {
        switch source {
        case .empty: return nil
        case .valid(_, let byteCount, _), .invalid(_, let byteCount, _): return byteCount
        }
    }

    mutating func receiveFile(name: String, data: Data) {
        mode = .merge
        do {
            let payload = try ImportExchange.parse(data: data, filename: name)
            source = .valid(name: name, byteCount: data.count, payload: payload)
        } catch let error as ImportReadError {
            source = .invalid(name: name, byteCount: data.count, message: error.inlineMessage)
        } catch {
            source = .invalid(name: name, byteCount: data.count, message: ImportReadError.userFacingMessage)
        }
    }

    mutating func failRead(name: String) {
        mode = .merge
        let label = name.isEmpty ? "Export" : name
        source = .invalid(name: label, byteCount: 0, message: ImportCopy.inlineError)
    }
}

enum ImportWriteGate {
    /// Merge writes as soon as the file is valid. Replace writes only after the confirm alert.
    /// Cancel on that alert leaves `replaceConfirmed` false, so nothing is written.
    static func shouldWrite(canImport: Bool, mode: ImportMode, replaceConfirmed: Bool) -> Bool {
        guard canImport else { return false }
        switch mode {
        case .merge: return true
        case .replaceBooks: return replaceConfirmed
        }
    }
}

enum ImportFileAccess {
    /// Reads a Files, AirDrop, or Share-sheet URL.
    /// Security-scoped URLs need `startAccessingSecurityScopedResource`.
    /// A false return still attempts the read: an Inbox copy is sometimes already readable.
    static func read(url: URL) throws -> ImportReadFile {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ImportReadError.notMaritimeExport
        }
        let name = url.lastPathComponent.isEmpty ? "Export" : url.lastPathComponent
        return ImportReadFile(name: name, data: data)
    }
}

enum ImportFilePresentation {
    static func kindLabel(filename: String) -> String {
        switch (filename as NSString).pathExtension.lowercased() {
        case "pdf": return "PDF"
        case "csv": return "CSV"
        default: return "File"
        }
    }

    static func sizeText(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = false
        if bytes >= 1_000_000 {
            formatter.allowedUnits = .useMB
        } else if bytes >= 1_000 {
            formatter.allowedUnits = .useKB
        } else {
            formatter.allowedUnits = .useBytes
        }
        return formatter.string(fromByteCount: Int64(max(0, bytes)))
    }

    static func detail(byteCount: Int, filename: String) -> String {
        "\(sizeText(byteCount)) \u{00B7} \(kindLabel(filename: filename))"
    }
}
