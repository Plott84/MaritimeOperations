import Foundation
import SwiftData

enum RigMoveOperation: String, CaseIterable, Identifiable {
    case anchorHandling = "Anchor Handling"
    case prelay = "Prelay"

    var id: String { rawValue }
}

@Model
final class RigMove {
    var id: UUID
    var rigName: String
    var date: Date
    var startTime: Date?
    var endTime: Date?
    var operationRaw: String
    var notes: String
    var isDone: Bool
    var createdAt: Date

    var operation: RigMoveOperation {
        get { RigMoveOperation(rawValue: operationRaw) ?? .anchorHandling }
        set { operationRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        rigName: String,
        date: Date = .now,
        startTime: Date? = nil,
        endTime: Date? = nil,
        operation: RigMoveOperation = .anchorHandling,
        notes: String = "",
        isDone: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.rigName = rigName
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.operationRaw = operation.rawValue
        self.notes = notes
        self.isDone = isDone
        self.createdAt = createdAt
    }
}
