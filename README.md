# Maritime Operations

Personal DPO logbook helper (iPhone, iOS 18+, SwiftUI + SwiftData).

## Open in Xcode

1. Open `test.xcodeproj` (target/module still named `test`; display name is **Maritime Operations**).
2. Select an iPhone Simulator (or a signed device).
3. Product → Run.

If `xcodebuild` can’t find iOS SDKs, ensure Xcode.app is selected:
`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`

## MVP included

- Floating tab shell with `safeAreaInset` (Main / Entries / Rig Moves / Tools / Export stubs)
- Design tokens (navy / blue / teal / gold)
- Unified `DPEntry` (timed + manual)
- Main DP timer: persists `startedAt`, elapsed via `TimelineView` (survives kill/relaunch)
- Entries list + Add Manual Entry (Mode / activity / Master’s initials optional)
- Configurable eligibility threshold (not hardcoded 1h/2h)

## Verify (QA P0)

1. Start DP → Stop → entry appears in Entries (source Timed).
2. Add Manual with duration only → same list (source Manual).
3. Start DP → background → kill app → relaunch → timer still running with correct elapsed.
4. Manual save with empty vessel or negative duration → blocked with field message.
5. Scroll Entries: last row not under tab bar; activity metadata wraps (no double truncation).
