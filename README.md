# Maritime Operations

Personal DPO logbook helper (iPhone, iOS 18+, SwiftUI + SwiftData).

## Open in Xcode

1. Open `MaritimeOperations.xcodeproj`.
2. Scheme: **MaritimeOperations**.
3. Select an iPhone Simulator (or a signed device) → Product → Run.

CLI tip if `xcodebuild` can’t find SDKs:
`export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`

## MVP included

- Floating tab shell with `safeAreaInset` (Main / Entries / Rig Moves / Tools / Export stubs)
- Design tokens (navy / blue / teal / gold)
- Unified `DPEntry` (timed + manual)
- Main DP timer: persists `startedAt`, elapsed via `TimelineView` (survives kill/relaunch)
- Stop surfaces save failures (timer keeps running on failure)
- Entries list + Add Manual Entry (Mode / activity / Master’s initials optional)
- Configurable eligibility threshold (not hardcoded 1h/2h)

## Verify (QA P0)

1. Start DP → Stop → entry appears in Entries (source Timed).
2. Add Manual with duration only → same list (source Manual).
3. Start DP → background → kill app → relaunch → timer still running with correct elapsed.
4. Manual save with empty vessel or negative duration → blocked with field message.
5. Scroll Entries: last row not under tab bar; activity metadata wraps.
