# Plan

## Scope

Implement the required `StudyPlanner` domain behavior in `Sources/StudyPlanner/StudyPlanner.swift` without changing the published API or the supplied public tests:

- `StudyItem` validation and validated `Codable` decoding.
- `StudyPlan` duplicate-ID validation, deterministic ordering, keyed decoding, and top-level array decoding.
- Category query, incomplete-minute total, and idempotent completion with unknown-ID errors.

Out of scope: the optional `importMerging` bonus. It keeps its signature but throws instead of calling `fatalError`, so it can never crash a test run.

## Acceptance criteria

- Blank or whitespace/newline-only title throws `.blankTitle`.
- `estimatedMinutes <= 0` throws `.nonPositiveEstimatedMinutes`.
- Title is checked before minutes (blank title + 0 minutes throws `.blankTitle`).
- Decoding a `StudyItem` runs the same validation; missing `isCompleted` defaults to `false`.
- `StudyPlan(items:)` throws `.duplicateID(id)` for the first ID that repeats, scanning in input order.
- Plan items are sorted by title, then by ID (plain `String` `<`, deterministic).
- `StudyPlan` decodes from keyed JSON `{"items": [...]}` through the validating initializer.
- `StudyPlan.decode(from:)` decodes a top-level JSON array (the fixture file).
- `items(in:)` returns only matching items in plan order.
- `incompleteMinutes()` sums minutes of items that are not completed.
- `markCompleted(id:)` throws `.unknownID(id)` for unknown IDs and leaves the plan unchanged; repeated calls are no-ops.

## Implementation steps

1. Write student tests first in `Tests/StudyPlannerTests/StudyPlannerStudentTests.swift`; confirm they compile.
2. `StudyItem.init` validation + custom `init(from:)` — `Sources/StudyPlanner/StudyPlanner.swift`.
3. `StudyPlan.init(items:)` duplicate check + title-then-ID sort — same file.
4. Keyed `StudyPlan.init(from:)` and `decode(from:)` — same file.
5. `items(in:)`, `incompleteMinutes()`, `markCompleted(id:)` — same file.
6. Run `swift test`, save curated output to `artifacts/swift-test-output.txt`.

## Risks

- Title ordering: uses plain `String` comparison (case-sensitive, not locale-aware) to stay deterministic across machines.
- Titles are stored as given; trimming is only used for the blank check.
- `isCompleted` is optional in JSON (defaults to `false`); other fields are required.
- `isCompleted` setter is `private(set)`, so completion goes through a `fileprivate` helper — public API unchanged.
- Toolchain: Command Line Tools alone lack XCTest on this machine; tests run with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

## `swift test` verification

| Date | Command | Result | Follow-up |
| --- | --- | --- | --- |
| 2026-10-01 | `swift build --build-tests` (before implementation) | Failed: `unable to resolve module dependency: 'XCTest'` (Command Line Tools selected) | Use Xcode toolchain via `DEVELOPER_DIR` |
| 2026-10-01 | `swift test` (after implementation) | 15 tests, 0 failures (3 starter + 12 student) | Saved to `artifacts/swift-test-output.txt` |
