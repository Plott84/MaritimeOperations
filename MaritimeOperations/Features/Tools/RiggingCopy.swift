import Foundation

/// User-facing strings for Slinging & Rigging. The screen and the tests share these.
enum RiggingCopy {
    static let title = "Slinging & Rigging"
    static let footer = "Aid, not authority."
    static let angleCaption = "Measured from vertical. L includes hook/shackle."
    static let chainAngleCaption = "Measured from vertical."
    static let legNote = "3- and 4-leg slings are calculated as 2-leg."
    static let chokeCaption = "Choke angle ≥120°; edges protected"
    static let assumptions = "Assumes CoG centred, legs equal. Tag overrides."
    static let highAngle = "High angle — check with lift plan / competent person."
    static let chainAmber = "Most blocks are rated vertical only. Check maker's limit; force must be checked by a competent person (LEEA 053)."
    static let blocked = "Outside rated range. Competent person only."
    static let heightTooTall = "Height can't be more than sling length"
    static let noReduction = "No capacity reduction at 0°."
    static let blocksApart = "Blocks must be apart."
    static let slingGuidanceLength = "Enter load, length and height, and tag WLL."
    static let slingGuidanceAngle = "Enter load, angle from vertical, and tag WLL."
    static let chainGuidance = "Enter load, block WLL and angle from vertical."
    static let pairGuidance = "Enter load and both angles from vertical."
    static let enterNumber = "Enter a number."
    static let loadPositive = "Enter a load above zero."
    static let tagPositive = "Enter a tag WLL above zero."
    static let wllPositive = "Enter a block WLL above zero."
    static let lengthPositive = "Sling length must be above zero."
    static let heightPositive = "Height must be above zero."
    static let angleNegative = "Angle is measured from vertical, starting at 0°."
    static let angleTooWide = "Angle can't be more than 90° from vertical."
    static let withinMarked = "Within marked WLL"
    static let withinBlock = "Within block WLL"
    static let exceeds = "Exceeds"
    static let compareHint = "Enter block WLL to compare."
    static let oneWLLMissing = "One block WLL is not entered."
    static let straightPull = "straight pull"

    static let staticStrings: [String] = [
        title, footer, angleCaption, chainAngleCaption, legNote, chokeCaption, assumptions,
        highAngle, chainAmber, blocked, heightTooTall, noReduction, blocksApart,
        slingGuidanceLength, slingGuidanceAngle, chainGuidance, pairGuidance,
        enterNumber, loadPositive, tagPositive, wllPositive, lengthPositive,
        heightPositive, angleNegative, angleTooWide, withinMarked, withinBlock,
        exceeds, compareHint, oneWLLMissing, straightPull
    ]

    static func trigLine(factor: String, tension: String) -> String {
        "Exact trig (info only): factor \(factor) · \(tension)/leg. Band decides pass/fail."
    }

    static func echo(angle: String, band: String) -> String {
        "β = \(angle)° from vertical · band \(band)"
    }

    static func chainEcho(angle: String, straight: Bool) -> String {
        straight
            ? "β = \(angle)° from vertical · \(straightPull)"
            : "β = \(angle)° from vertical"
    }
}
