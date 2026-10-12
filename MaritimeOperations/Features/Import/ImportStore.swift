import Foundation
import SwiftData

/// Applies an `ImportPlan` to the SwiftData store.
/// Books absent from the file are not fetched for deletion.
@MainActor
enum ImportStore {
    static func apply(mode: ImportMode, payload: ImportPayload, context: ModelContext) throws -> ImportReport {
        let existingDP = try context.fetch(FetchDescriptor<DPEntry>())
        let existingMoves = try context.fetch(FetchDescriptor<RigMove>())
        let existingROV = try context.fetch(FetchDescriptor<ROVEntry>())
        let existingCrane = try context.fetch(FetchDescriptor<CraneEntry>())

        let existing = ImportLibrary(
            dp: existingDP.map(DPRecord.init),
            moves: existingMoves.map(RigMoveRecord.init),
            rov: existingROV.map(ROVRecord.init),
            crane: existingCrane.map(CraneRecord.init)
        )
        let plan = ImportPlanner.plan(mode: mode, existing: existing, payload: payload)

        // Rig-move photos are not part of the export. Keep the photo already stored for a move id
        // that the file is writing back.
        var photos: [UUID: Data] = [:]
        for move in existingMoves {
            if let photo = move.photoJPEG {
                photos[move.id] = photo
            }
        }

        for entry in existingDP where plan.deleteDP.contains(entry.id) {
            context.delete(entry)
        }
        for move in existingMoves where plan.deleteMoves.contains(move.id) {
            context.delete(move)
        }
        for entry in existingROV where plan.deleteROV.contains(entry.id) {
            context.delete(entry)
        }
        for entry in existingCrane where plan.deleteCrane.contains(entry.id) {
            context.delete(entry)
        }

        for record in plan.insertDP {
            context.insert(record.makeModel())
        }
        for record in plan.insertMoves {
            let move = record.makeModel()
            if let photo = photos[record.id] {
                move.photoJPEG = photo
            }
            context.insert(move)
        }
        for record in plan.insertROV {
            context.insert(record.makeModel())
        }
        for record in plan.insertCrane {
            context.insert(record.makeModel())
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return plan.report
    }
}
