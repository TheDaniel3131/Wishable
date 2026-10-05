# Implementation Plan: Wishable

## Overview

This plan builds Wishable in strict dependency order so each step compiles and integrates with the previous ones, leaving no orphaned code. We scaffold the Flutter project and its layered folders first, then stand up the Drift schema and the conditional-import connection opener. We then build the pure domain layer (models, the `LifecyclePolicy` state machine, validators, and JSON/CSV serializers), followed by the Drift-backed repositories and the `BackupService`. On top of that we wire the Riverpod controllers, then the GoRouter navigation shell and the Material 3 responsive views, the backup/restore UI, and finally the celebration overlay.

Property-based tests implement each of the 17 correctness properties from the design, placed next to the unit they exercise so defects surface early. Each property test is tagged `// Feature: wishable, Property {n}: ...`. Example, widget, integration, and architecture tests cover the input-invariant and UI-specific criteria. The language is **Dart (Flutter)** as specified throughout the design, so no implementation-language question is required.

## Tasks

- [x] 1. Scaffold project and layered architecture
  - Initialize a Flutter app targeting web, Windows, macOS, Linux, Android, iOS
  - Add dependencies: `drift`, `sqlite3`, `riverpod`/`flutter_riverpod`, `go_router`, `file_picker`, `path_provider`, `uuid`; dev dependencies: `drift_dev`, `build_runner`, `test`/`flutter_test`, and a Dart property-testing library (`glados`)
  - Create the four-layer folder structure (`presentation/`, `application/`, `domain/`, `data/`) plus `data/connection/`
  - Enable Material 3 in `ThemeData` and configure the Material Symbols icon set
  - _Requirements: 13.1, 13.4, 14.4_

- [x] 2. Define the Drift schema, connection opener, and database
  - [x] 2.1 Define Drift tables (Wishes, Categories, Settings) and `AppDatabase`
    - Implement `Wishes` (UUID PK, title min length 1, nullable description, category FK, intEnum priority/status, integer progress with 0–100 CHECK, UTC createdAt/updatedAt), `Categories` (UUID PK, unique name, isPreset), `Settings` (key/value)
    - Define `AppDatabase` and run `build_runner` to generate Drift code
    - Seed the five preset categories (Learn, Travel, Buy, Save, Achieve) in the migration `onCreate`
    - _Requirements: 1.5, 2.4, 3.2, 3.3, 4.1, 5.1, 6.1, 10.1, 14.1, 14.2_

  - [x] 2.2 Implement the conditional-import connection opener
    - Create `connection/connection.dart` with `openConnection()` dispatching via conditional imports to `native.dart` (`NativeDatabase.createInBackground` under `path_provider` documents dir), `web.dart` (`WasmDatabase.open` with OPFS/IndexedDB fallback), and `unsupported.dart`
    - Ship `sqlite3.wasm` and `drift_worker.js` assets in `web/`
    - _Requirements: 10.1, 13.1_

  - [x] 2.3 Write smoke test for preset category seeding
    - On a fresh in-memory database, assert exactly the five preset categories exist
    - _Requirements: 3.2_

- [x] 3. Implement the pure domain models and enums
  - Implement `LifecycleStatus`, `Priority` enums; `LifecycleEvent` sealed hierarchy (`StartEvent`, `CompleteEvent`, `ReopenEvent`, `ProgressChanged`)
  - Implement immutable `Wish`, `Category`, `AppSettings` value objects with `copyWith` and value equality; `WishDraft`/`WishEdit` input types
  - _Requirements: 1.1, 1.3, 1.4, 3.1, 4.1, 5.1, 6.1, 14.1, 14.2_

- [x] 4. Implement the LifecyclePolicy state machine
  - [x] 4.1 Implement `LifecyclePolicy` as a pure function `(status, progress, event) -> (status, progress)`
    - Encode all transition rules: Start (Active→In_Progress), ProgressChanged 0→>0 (→In_Progress), ProgressChanged 100 / Complete (→Completed, progress=100), Reopen (Completed→In_Progress, retain progress), reject out-of-range progress
    - Enforce invariants: progress ∈ [0,100], status==Completed ⇒ progress==100, progress>0 ⇒ status≠Active
    - _Requirements: 5.3, 5.4, 6.1, 6.2, 6.3, 6.4_

  - [x] 4.2 Write property test for the lifecycle state machine
    - **Property 9: Lifecycle state machine preserves its invariants**
    - **Validates: Requirements 1.1, 5.3, 5.4, 6.1, 6.2, 6.3, 6.4**
    - Tag: `// Feature: wishable, Property 9: ...`

- [x] 5. Implement domain validation
  - [x] 5.1 Implement `WishValidator`
    - Reject empty/whitespace titles (`TitleRequiredError`); enforce priority-set membership; enforce progress bounds 0–100
    - Apply default Priority `Medium` when a draft omits priority
    - _Requirements: 1.2, 1.4, 2.2, 4.3, 5.2_

  - [x] 5.2 Write property test for title validation
    - **Property 2: Title validation rejects blank titles and preserves state**
    - **Validates: Requirements 1.2, 2.2**
    - Tag: `// Feature: wishable, Property 2: ...`

  - [x] 5.3 Write property test for default priority
    - **Property 3: Default priority is Medium**
    - **Validates: Requirements 1.4**
    - Tag: `// Feature: wishable, Property 3: ...`

  - [x] 5.4 Write property test for progress bounds enforcement
    - **Property 8: Progress bounds are enforced**
    - **Validates: Requirements 5.1, 5.2**
    - Tag: `// Feature: wishable, Property 8: ...`

- [x] 6. Implement JSON and CSV serializers
  - [x] 6.1 Implement `WishJsonCodec`
    - Encode/decode schema-versioned object with `wishes` array; ISO-8601 UTC timestamps; stable lowercase enum tokens; categories embedded by name; reject invalid enum/parse with descriptive errors
    - _Requirements: 11.2, 12.1, 12.4_

  - [x] 6.2 Implement `WishCsvCodec`
    - Encode/decode fixed-column CSV with RFC-4180 quoting (commas, quotes, newlines quoted; embedded quotes doubled); same enum tokens and ISO-8601 UTC timestamps as JSON
    - _Requirements: 11.3, 12.1, 12.5_

  - [x] 6.3 Write property test for JSON round-trip equivalence
    - **Property 16: JSON export/import round-trip equivalence**
    - **Validates: Requirements 11.2, 12.1, 12.4**
    - Tag: `// Feature: wishable, Property 16: ...`

  - [x] 6.4 Write property test for CSV round-trip equivalence
    - **Property 17: CSV export/import round-trip equivalence** (generate titles/descriptions containing commas, quotes, newlines)
    - **Validates: Requirements 11.3, 12.1, 12.5**
    - Tag: `// Feature: wishable, Property 17: ...`

- [x] 7. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. Implement the data-access repositories
  - [x] 8.1 Define repository interfaces
    - Declare `WishRepository`, `CategoryRepository`, `SettingsRepository`, `BackupService` abstract interfaces in the domain/data boundary (Domain-only types; no Drift leakage)
    - _Requirements: 14.3_

  - [x] 8.2 Implement Drift-backed `WishRepository`
    - Implement create/update/delete/getById; `watchAll`, `watchByStatus`, `watchByCategory` reactive streams; `applyProgress` and `transition` routed through `LifecyclePolicy`; `getAll`/`replaceAll`; assign UUID and UTC timestamps on create, update `updatedAtUtc` on edit, preserve `id` on edit
    - _Requirements: 1.1, 1.3, 1.5, 2.1, 2.3, 2.4, 3.1, 3.4, 4.1, 5.1, 5.3, 5.4, 6.1, 6.2, 6.3, 6.4, 6.5, 8.1, 9.1, 9.2, 9.3, 9.4, 9.5, 10.1, 10.4, 14.1, 14.2_

  - [x] 8.3 Implement Drift-backed `CategoryRepository`
    - Implement `getAll`, `watchAll`, and idempotent `getOrCreateByName` (reuse existing by name, no duplicates)
    - _Requirements: 3.1, 3.3_

  - [x] 8.4 Implement Drift-backed `SettingsRepository`
    - Implement `load`/`save` over the Settings key/value table
    - _Requirements: 10.1_

  - [x] 8.5 Implement priority sort helper
    - Provide a stable sort producing a non-increasing High→Low permutation
    - _Requirements: 4.2_

  - [x] 8.6 Write property test for persistence round-trip
    - **Property 1: Persistence round-trip preserves all fields** (use `NativeDatabase.memory()`; include close/reopen)
    - **Validates: Requirements 1.1, 1.3, 2.1, 2.3, 3.1, 4.1, 9.5, 10.4**
    - Tag: `// Feature: wishable, Property 1: ...`

  - [x] 8.7 Write property test for UTC timestamp recording and ordering
    - **Property 4: Timestamps are recorded in UTC with correct ordering**
    - **Validates: Requirements 1.5, 2.4, 14.2**
    - Tag: `// Feature: wishable, Property 4: ...`

  - [x] 8.8 Write property test for identifier uniqueness and stability
    - **Property 10: Wish identifiers are unique and stable**
    - **Validates: Requirements 14.1**
    - Tag: `// Feature: wishable, Property 10: ...`

  - [x] 8.9 Write property test for get-or-create idempotence
    - **Property 5: Category get-or-create is idempotent**
    - **Validates: Requirements 3.3**
    - Tag: `// Feature: wishable, Property 5: ...`

  - [x] 8.10 Write property test for filtering soundness and completeness
    - **Property 6: Filtering is sound and complete** (by Category, by Lifecycle_Status, and "all")
    - **Validates: Requirements 3.4, 6.5, 9.1, 9.2, 9.3, 9.4**
    - Tag: `// Feature: wishable, Property 6: ...`

  - [x] 8.11 Write property test for priority sort permutation
    - **Property 7: Priority sort is an ordered permutation**
    - **Validates: Requirements 4.2**
    - Tag: `// Feature: wishable, Property 7: ...`

  - [x] 8.12 Write property test for confirmed delete removing exactly the target
    - **Property 13: Confirmed delete removes exactly the target**
    - **Validates: Requirements 8.1**
    - Tag: `// Feature: wishable, Property 13: ...`

- [x] 9. Implement the BackupService
  - [x] 9.1 Implement export operations (database, JSON, CSV)
    - Read a transactional snapshot; write to a temp path then move into place; on failure delete any partial file and leave the DB unchanged; surface descriptive errors
    - _Requirements: 11.1, 11.2, 11.3, 11.4_

  - [x] 9.2 Implement import inspect + transactional restore
    - `inspect` validates fully before any write and rejects malformed/unreadable files with a descriptive error; `restore` runs `replaceAll` inside a single Drift transaction (all-or-nothing)
    - _Requirements: 12.1, 12.2_

  - [x] 9.3 Write property test for export failure cleanup
    - **Property 14: Export failure cleans up and preserves the database** (inject failing I/O)
    - **Validates: Requirements 11.4**
    - Tag: `// Feature: wishable, Property 14: ...`

  - [x] 9.4 Write property test for malformed import rejection
    - **Property 15: Malformed import is rejected without side effects** (inject malformed content)
    - **Validates: Requirements 12.2**
    - Tag: `// Feature: wishable, Property 15: ...`

  - [x] 9.5 Write integration test for database export durability
    - Export the database file, open the copy, assert equivalent wishes + settings
    - _Requirements: 11.1, 10.4_

- [x] 10. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 11. Implement Riverpod providers and controllers
  - [x] 11.1 Define Riverpod providers for database and repositories
    - Expose `AppDatabase`, `WishRepository`, `CategoryRepository`, `SettingsRepository`, `BackupService` as providers consumed via interfaces only
    - _Requirements: 14.3_

  - [x] 11.2 Implement `WishListController`
    - Watch repository streams per view (all/active/in-progress/completed and by category); apply priority sort/filter
    - _Requirements: 4.2, 6.5, 9.1, 9.2, 9.3, 9.4_

  - [x] 11.3 Implement `WishEditController`
    - Validate and persist create/edit; surface `TitleRequiredError` and invalid-priority errors inline
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.1, 2.2, 2.3, 4.1, 4.3_

  - [x] 11.4 Implement `WishActionController`
    - Progress updates, lifecycle transitions via repository, delete-with-confirmation (cancel is a no-op)
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 6.2, 6.3, 6.4, 8.1, 8.2, 8.3_

  - [x] 11.5 Implement `CelebrationController`
    - Detect transitions whose resulting status is `Completed` and emit exactly one celebration event carrying the completed Wish's title
    - _Requirements: 7.1, 7.3_

  - [x] 11.6 Implement `BackupController`
    - Drive export targets; drive import/restore with replace-confirmation and descriptive error surfacing
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 12.1, 12.2, 12.3_

  - [x] 11.7 Write property test for celebration event emission
    - **Property 11: Completion emits a celebration event carrying the title**
    - **Validates: Requirements 7.1, 7.3**
    - Tag: `// Feature: wishable, Property 11: ...`

  - [x] 11.8 Write property test for cancelled delete being a no-op
    - **Property 12: Cancelled delete is a no-op**
    - **Validates: Requirements 8.3**
    - Tag: `// Feature: wishable, Property 12: ...`

- [x] 12. Implement GoRouter navigation and the responsive app shell
  - [x] 12.1 Configure GoRouter with the StatefulShellRoute
    - Define `StatefulShellRoute.indexedStack` for the four lifecycle tabs plus settings; routed children for detail (`/wish/:id`), editor (`/wish/:id/edit`), new (`/wish/new`); preserve per-tab state
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

  - [x] 12.2 Implement the responsive shell
    - `LayoutBuilder` switches between bottom `NavigationBar` (width ≤ 600 px, single column) and `NavigationRail` + two-pane layout (width > 600 px); Material 3 components and Material Symbols icons
    - _Requirements: 13.2, 13.3, 13.4_

  - [x] 12.3 Write widget test for responsive layout breakpoints
    - Assert single-column vs rail/multi-column at widths 360, 600, 601, 1200
    - _Requirements: 13.2, 13.3_

- [x] 13. Implement the list and detail/editor views
  - [x] 13.1 Implement the four lifecycle list views
    - One view per status plus "all", each bound to `WishListController`; open a Wish to its detail route
    - _Requirements: 9.1, 9.2, 9.3, 9.4_

  - [x] 13.2 Implement the Wish detail view
    - Render all fields of the selected Wish; expose start/complete/reopen/progress/delete actions
    - _Requirements: 9.5, 5.1, 6.2, 6.3, 6.4, 8.2_

  - [x] 13.3 Implement the create/edit form
    - Title, optional description, category (with get-or-create), priority (default Medium), progress; inline validation errors
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.1, 2.2, 2.3, 3.1, 4.1_

  - [x] 13.4 Write widget tests for detail view and delete confirmation
    - Detail renders all fields; delete triggers a confirmation dialog
    - _Requirements: 9.5, 8.2_

- [x] 14. Implement the Settings / backup-restore view
  - [x] 14.1 Implement the Settings view UI
    - Export buttons (database/JSON/CSV) wired to `BackupController`; import file picker; replace-restore confirmation dialog; error message surfacing
    - _Requirements: 11.1, 11.2, 11.3, 12.1, 12.2, 12.3_

  - [x] 14.2 Write widget test for replace-restore confirmation
    - Initiating a restore that replaces data prompts for confirmation before modifying the database
    - _Requirements: 12.3_

- [x] 15. Implement the Celebration overlay and wire it to completion
  - [x] 15.1 Implement the Celebration View as a modal overlay
    - Present above the current route showing "Wish fulfilled" and the completed Wish's title; dismiss returns to the originating view; driven by `CelebrationController` events
    - _Requirements: 7.1, 7.2, 7.3_

  - [x] 15.2 Write widget test for celebration content and dismissal
    - Renders "Wish fulfilled" and the title; dismiss restores the prior route
    - _Requirements: 7.1, 7.2, 7.3_

- [x] 16. Wire the application entry point together
  - Assemble `main.dart`: initialize the connection/`AppDatabase`, wrap in the Riverpod `ProviderScope`, mount the GoRouter + responsive shell, apply the Material 3 theme; load persisted Wishes on startup
  - _Requirements: 10.1, 10.4, 13.1, 13.4_

- [x] 17. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 18. Add architecture, offline, and configuration safeguard tests
  - [x] 18.1 Write the data-access boundary architecture test
    - Source-level test asserting no file under presentation/application imports `package:drift/...` or the generated database directly
    - _Requirements: 14.3_

  - [x] 18.2 Write offline and no-backend smoke tests
    - CRUD succeeds with no network dependency; assert no account/server/hosted-DB dependency is compiled in
    - _Requirements: 10.2, 10.3, 14.4_

  - [x] 18.3 Write Material 3 configuration smoke test
    - Assert `ThemeData.useMaterial3` is true and the Material Symbols icon set is configured
    - _Requirements: 13.4_

- [x] 19. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional (tests) and can be skipped for a faster MVP, though they implement the 17 correctness properties and the UI/architecture guarantees.
- Each of Properties 1–17 is implemented by exactly one property-based test, tagged `// Feature: wishable, Property {n}: ...`, placed next to the unit it exercises.
- Each task references the specific requirement sub-clauses it covers for traceability.
- Checkpoints provide incremental validation at natural layer boundaries.
- The implementation language is Dart (Flutter) per the design; no language-selection step is needed.
- CI building all six platforms (R13.1) is an operational concern outside code-authoring scope and is not a coding task here.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["2.1", "3.1"] },
    { "id": 1, "tasks": ["2.2", "2.3", "4.1", "5.1", "6.1", "6.2"] },
    { "id": 2, "tasks": ["4.2", "5.2", "5.3", "5.4", "6.3", "6.4", "8.1"] },
    { "id": 3, "tasks": ["8.2", "8.3", "8.4", "8.5"] },
    {
      "id": 4,
      "tasks": [
        "8.6",
        "8.7",
        "8.8",
        "8.9",
        "8.10",
        "8.11",
        "8.12",
        "9.1",
        "9.2"
      ]
    },
    { "id": 5, "tasks": ["9.3", "9.4", "9.5", "11.1"] },
    { "id": 6, "tasks": ["11.2", "11.3", "11.4", "11.5", "11.6"] },
    { "id": 7, "tasks": ["11.7", "11.8", "12.1", "14.1"] },
    { "id": 8, "tasks": ["12.2", "13.1"] },
    { "id": 9, "tasks": ["12.3", "13.2", "13.3", "14.2", "15.1"] },
    { "id": 10, "tasks": ["13.4", "15.2", "16"] },
    { "id": 11, "tasks": ["18.1", "18.2", "18.3"] }
  ]
}
```

## Post-completion fixes (applied after the initial build was verified)

These were found while running the app (`flutter run -d chrome`) and fixed in place. They are recorded here for traceability.

- [x] F1. Fix recursive-getter analyzer error in the Drift schema
  - `lib/data/tables.dart`: the `progress` column's CHECK referenced its own getter (`progress.isBetweenValues(...)`), an infinite recursion. Rewrote it as `customConstraint('NOT NULL CHECK (progress BETWEEN 0 AND 100)')`.
  - _Requirements: 5.1, 5.2_

- [x] F2. Fix web build failure — `dart:ffi` leaking into the web target
  - `lib/data/repositories/drift_backup_service.dart` imported `package:drift/native.dart` unconditionally (for the raw-database import), dragging `dart:ffi`/`sqlite3` native code into the web build and breaking `flutter build web`.
  - Introduced a conditional-import seam: `lib/data/connection/file_database.dart` (re-export), `file_database_native.dart` (real `NativeDatabase` opener), `file_database_web.dart` (throws `UnsupportedError`). The backup service now calls `openFileExecutor(path)` through the seam. Raw-database (`.sqlite`) backup is native-only; JSON/CSV work on all platforms.
  - _Requirements: 10.1, 11.1, 12.1, 13.1, 14.3_

- [x] F3. Replace placeholder Material Symbols font
  - `assets/fonts/MaterialSymbolsOutlined.ttf` was an 11-byte stub containing the literal text `PLACEHOLDER`, causing "Failed to load font" at runtime (the `AppIcons` glyphs did not render). Replaced with the real Material Symbols Outlined variable font (valid TrueType).
  - _Requirements: 13.4_

- [x] F4. Add the missing "+" create button (missing functionality)
  - The empty-state told users to "Tap + to add your first aspiration," but no control navigated to `/wish/new`, so a Wish could not be created from the UI. Added `FloatingActionButton.extended` ("New Wish") to `WishListView` (`lib/presentation/views/wish_list_view.dart`) wired to `context.goNamed(WishRoutes.newWishName)`. The create form and its persistence were already implemented; only the entry point was missing.
  - _Requirements: 1.1, 9.1, 9.2, 9.3, 9.4_

- Note (not a code bug): the web tab favicon not appearing is Chrome's aggressive favicon caching on the dev server; `web/favicon.png` and `web/icons/*.png` are valid PNGs. A hard refresh / cache clear shows it.

## Follow-up feature: Authentication / App Lock

A new feature spec has been authored at `.kiro/specs/auth/` (`requirements.md`, `design.md`, `tasks.md`). It adds a **local app lock** (passcode + biometric gate) that preserves Wishable's local-first, no-backend guarantee. Remote accounts/sync is explicitly out of scope and would require product-owner approval and a separate backend. See that spec's decision gates before implementing.
