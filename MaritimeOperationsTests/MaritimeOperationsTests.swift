import Testing
import Foundation
@testable import MaritimeOperations

struct MaritimeOperationsTests {
    @Test func eligibilityUsesConfiguredThreshold() {
        let config = EligibilityConfig(minimumHoursForEligibleDay: 1.0)
        #expect(config.isEligible(durationHours: 1.0))
        #expect(!config.isEligible(durationHours: 0.9))

        let twoHour = EligibilityConfig(minimumHoursForEligibleDay: 2.0)
        #expect(!twoHour.isEligible(durationHours: 1.5))
        #expect(twoHour.isEligible(durationHours: 2.0))
    }

    @Test func timerFormatterHandlesHours() {
        #expect(AppFormatters.timerString(from: 0) == "00:00")
        #expect(AppFormatters.timerString(from: 65) == "01:05")
        #expect(AppFormatters.timerString(from: 3661) == "01:01:01")
    }

    @Test func rigMoveHoursCrossMidnight() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let finish = start.addingTimeInterval(4 * 3600)
        #expect(RigMoveCheck.workedHours(start: start, finish: finish) == 4)
        #expect(RigMoveCheck.workedHours(start: start, finish: start.addingTimeInterval(-60)) == nil)
        #expect(
            RigMoveCheck.block(
                rigName: "Rig",
                start: start,
                finish: start.addingTimeInterval(-60),
                operation: .towing,
                projectText: ""
            ) == .finishBeforeStart
        )
        #expect(
            RigMoveCheck.block(
                rigName: "  ",
                start: start,
                finish: finish,
                operation: .towing,
                projectText: ""
            ) == .missingRigName
        )
        #expect(
            RigMoveCheck.block(
                rigName: "Rig",
                start: start,
                finish: finish,
                operation: .project,
                projectText: "  "
            ) == .missingProjectText
        )
        #expect(
            RigMoveCheck.block(
                rigName: "Rig",
                start: start,
                finish: finish,
                operation: .project,
                projectText: "Lay"
            ) == nil
        )
        #expect(
            RigMoveCheck.block(
                rigName: "Rig",
                start: start,
                finish: finish,
                operation: .towing,
                projectText: "",
                hasOther: true,
                otherEquipment: "  "
            ) == .missingOtherEquipment
        )

    }

    @Test func runningTimerEntryBlocksListDelete() {
        let started = Date(timeIntervalSince1970: 1_700_000_000)
        let live = DPEntry(
            source: .timed,
            date: started,
            startTime: started,
            endTime: nil,
            durationHours: 0,
            vessel: ""
        )
        #expect(live.isRunningTimerEntry(sessionStartedAt: started))
        #expect(!live.isRunningTimerEntry(sessionStartedAt: nil))

        let finished = DPEntry(
            source: .timed,
            date: started,
            startTime: started,
            endTime: started.addingTimeInterval(3600),
            durationHours: 1,
            vessel: "Ship"
        )
        #expect(!finished.isRunningTimerEntry(sessionStartedAt: started))

        let otherStart = DPEntry(
            source: .timed,
            date: started,
            startTime: started.addingTimeInterval(10),
            endTime: nil,
            durationHours: 0,
            vessel: ""
        )
        #expect(!otherStart.isRunningTimerEntry(sessionStartedAt: started))
    }

    @Test func deleteEntryPromptCopyIsLocked() {
        #expect(DeleteEntryPrompt.confirm == "Delete this entry? Its hours come off your total.")
    }

}
