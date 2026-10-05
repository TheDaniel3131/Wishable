# Implementation Plan: Authentication / App Lock

## Overview

This plan builds the local app lock in strict dependency order so each step compiles and integrates with the previous ones. We add the pinned dependencies first, then the pure `domain/auth` units (state, policy, hasher, lockout) with their property tests, then the `data/auth` secure store and biometric interfaces behind a conditional-import seam, then the Riverpod `AuthController`, then the presentation `AuthGate` + `LockScreen` + `PasscodeSetupView`, and finally the auto-lock lifecycle wiring and the entry-point integration. The offline/no-backend architecture test stays green throughout.

The language is **Dart (Flutter)**, matching the existing codebase. **Both** Option A (local app lock) and Option B (remote accounts + sync) are in scope. Phase 1 (tasks 1–10) builds Option A — self-contained, no network. Phase 2 (tasks 11–16) layers Option B on top, reusing the same `AuthController`/provider surface. The core invariant becomes **offline-first with optional sync** (requirement R14): the local app must build and run with the remote layer unconfigured.

> **Decision gates for the product owner:**
>
> - **Phase 2 backend**: Option B needs a backend choice — **Supabase** (recommended default), **Firebase**, or a **custom** server — and an **auth method** (email-password / OAuth / both). Phase 2 network code (tasks 12–14) is written only once these are chosen; everything up to the adapter interface is backend-agnostic and can be built regardless.
> - **Data-at-rest (R9)**: default is UI-access gate only, clearly labeled. Database encryption (task 7) is **optional** and off by default until approved.
> - **Local reset behavior**: with no server there is no local "forgot passcode" recovery. Decide whether a reset disables the lock (clearing protection) or wipes protected data. Task 6.3 encodes the chosen behavior. (Once Option B is signed in, the account provides recovery independent of the local passcode.)

## Tasks

- [x] 1. Add dependencies and the auth folder scaffold
  - Added pinned `flutter_secure_storage ^9.2.2`, `local_auth ^2.3.0`, and `crypto ^3.0.5` to `pubspec.yaml`
  - Created `domain/auth/`, `data/auth/`, `application/auth/`, `presentation/auth/` folders
  - `flutter pub get` succeeded; `flutter analyze` clean
  - _Requirements: 7.1, 8.1_

- [x] 2. Implement the pure domain units
  - [x] 2.1 Implemented `AuthState` sealed hierarchy and `AuthCredentials` value type
    - `AuthUnconfigured | AuthLocked | AuthUnlocked | AuthCoolingDown(remaining)`; immutable `AuthCredentials` (verifier, salt, kdf params, kind, biometricEnabled, lockTimeout) + `AuthFailureState`
    - _Requirements: 1.1, 2.1, 2.2, 4.2_
  - [x] 2.2 Implemented `PasscodePolicy`
    - PIN ≥ 4 digits / password ≥ 6 chars; descriptive errors; confirmation match; pure
    - _Requirements: 1.3, 1.4_
  - [x] 2.3 Implemented `PasscodeHasher` (PBKDF2-HMAC-SHA256 over `package:crypto`)
    - `enroll` → random salt + verifier (passcode never stored); `verify` → constant-time comparison; tunable KDF cost; injectable salt source
    - _Requirements: 1.5, 2.4, 7.1, 7.3_
  - [x] 2.4 Implemented `LockoutPolicy`
    - Pure (failures, last-failure, injected clock) → allowed / remaining cooldown with doubling backoff capped at max; reset on success
    - _Requirements: 4.1, 4.2, 4.3_

- [x] 3. Domain property/unit tests (16 pass)
  - [x] 3.1 Property 1: passcode verifier round-trip — `// Feature: auth, Property 1`
    - _Requirements: 1.5, 2.4_
  - [x] 3.2 Property 2: lockout backoff non-decreasing + capped, resets on success — `// Feature: auth, Property 2`
    - _Requirements: 4.1, 4.3_
  - [x] 3.3 Policy unit tests: PIN/password minimums, mismatch rejection
    - _Requirements: 1.3, 1.4_

- [x] 4. Data layer behind interfaces + seam
  - [x] 4.1 `AuthStore` and `BiometricAuthenticator` interfaces (Drift-free, plugin-free)
    - _Requirements: 7.1, 3.1_
  - [x] 4.2 `SecureAuthStore` over `flutter_secure_storage` (JSON + base64; verifier/salt/params/flags only; never plaintext; `clear()` removes all; plugin import confined to the data layer)
    - _Requirements: 7.1, 7.2, 5.2_
  - [x] 4.3 `LocalAuthBiometric` over `local_auth` (returns false on unavailable/cancel/fail)
    - _Requirements: 3.1, 3.3, 3.4_
  - [x] 4.4 Secure-store test (5 pass): write→read round-trip; no plaintext passcode in payload; `clear()` empties it
    - _Requirements: 7.1, 7.3, 5.2_

- [x] 5. Application layer
  - [x] 5.1 Interface-typed providers (store, biometric, hasher, lockout, injectable clock, controller)
    - _Requirements: 8.1_
  - [x] 5.2 `AuthController extends Notifier<AuthState>` (build unconfigured/locked; enroll; unlock; unlockBiometric; changePasscode; disable; lock; biometric/timeout prefs; no network I/O) + `AuthOutcome` result type
    - _Requirements: 1, 2, 3, 4, 5, 6.2, 8.1_
  - [x] 5.3 Controller tests (10 pass) with fakes + injected clock
    - _Requirements: 1, 2, 3, 4, 5_

- [x] 6. Presentation layer
  - [x] 6.1 `AuthGate` wrapping the app (mounted in `main.dart`; withholds Wish UI while Locked/CoolingDown; owns the auto-lock lifecycle observer)
    - _Requirements: 2.1, 6.2_
  - [x] 6.2 `LockScreen` (passcode entry, biometric button when available+enabled, non-revealing errors, live cooldown countdown)
    - _Requirements: 2.2, 2.3, 3.1, 4.2_
  - [x] 6.3 `PasscodeSetupView` in Settings (enroll / change / disable with confirmation + current-passcode checks; biometric toggle; labels that the lock protects UI access only)
    - _Requirements: 1, 5, 9.2_
  - [x] 6.4 Widget tests (3 pass): gate hides/reveals Wish UI by state and after unlock
    - _Requirements: 2.1, 2.3, 3.1, 3.4, 4.2, 1.3, 1.4, 5.1, 5.2_

- [ ] 7. (Optional, gated) Database encryption for data-at-rest
  - Only if the product owner opts in (R9). Derive the DB key from the passcode via the KDF; require it in the connection opener; re-key atomically on passcode change; isolate to `data/connection/`
  - _Requirements: 9.1, 9.3_

- [ ] 8. Wire auto-lock and the entry point
  - Add the app-lifecycle/focus observer that calls `AuthController.lock()` after the `lockTimeout`; mount `AuthGate` at the root in `main.dart` (inside `ProviderScope`, around `MaterialApp.router`); persist and restore `lockTimeout`
  - _Requirements: 6.1, 6.2, 6.3_

- [x] 9. Guard the invariant (offline-first)
  - The existing `data_access_boundary_test` and `offline_no_backend_test` stay green: no `presentation/`/`application/` auth file imports `flutter_secure_storage`, `local_auth`, or `package:drift/...` (the controller/providers import the specific interface/concrete files, not the data barrel), and no network/backend dependency is introduced by Option A. (This test is further revised in Phase 2 task 16 to the full offline-first check once the remote layer exists.)
  - _Requirements: 8.1, 8.2, 8.3_

- [x] 10. Phase 1 checkpoint — Option A complete
  - `flutter analyze` clean; `flutter test` 86/86 pass (34 new auth tests); `flutter build web` succeeds (secure storage + biometrics degrade gracefully on web). Option A ships independently of Phase 2.
  - _Requirements: 3.4, 7.2, 8.2_

## Phase 2 — Option B: remote accounts + sync

> **Decisions made:** backend = **PocketBase** (self-hosted single binary, SQLite-based, free); auth method = **both** (email/password + OAuth2). Implemented against the official `pocketbase` Dart SDK. Setup guide: `docs/pocketbase/README.md`.

- [x] 11. Backend-agnostic account/sync domain + interfaces
  - [x] 11.1 `domain/account/`: `Account`, `AccountSession` (SignedOut | SignedIn | AccountSessionError), `SyncState` (SyncIdle | Syncing | SyncOffline | SyncError) — pure, no secrets
    - _Requirements: 10.2, 11.1, 12.1_
  - [x] 11.2 `AccountAuthService` and `SyncService` interfaces in `data/account/` (backend-agnostic)
    - _Requirements: 10.1, 11.1, 12.1_
  - [x] 11.3 Drift migration v1→v2: nullable `deletedAtUtc` tombstone column (append-only, backward-compatible; existing data preserved)
    - _Requirements: 12.2_

- [x] 12. PocketBase adapter (`data/account/remote/`)
  - `pocketbase_auth_service.dart` (authWithPassword + authWithOAuth2 via injected URL launcher, session restore + authRefresh, sessionChanges) and `pocketbase_sync_service.dart` (owner-scoped `wishes` collection, push/pull/reconcile, soft-delete tombstone). Tokens persisted via the `SessionStore` secure seam. `pocketbase` SDK imported ONLY here (+ the one composition-root provider). Added `pocketbase`, `connectivity_plus`.
  - _Requirements: 10.1, 10.2, 10.3, 11.1, 11.2, 11.3, 11.4, 12.1_

- [x] 13. Account + sync application layer
  - [x] 13.1 `AccountController extends Notifier<AccountSession>`: sign-up/in (email + OAuth), sign-out, restore on build
    - _Requirements: 10, 11_
  - [x] 13.2 `SyncController`: connectivity-aware; pull + resolve category names → pure `mergeSync` (last-write-wins by `updatedAtUtc`, tombstone for delete-vs-edit) → `replaceAll` → push; errors leave local DB consistent
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5_
  - [x] 13.3 Interface-typed providers; concrete PocketBase adapters bound only in provider bodies, inert no-ops when unconfigured
    - _Requirements: 14.2_

- [x] 14. Account presentation + A/B interaction
  - [x] 14.1 `account_view.dart` in Settings (sign-in/up/out, email + OAuth) and `sync_status_indicator.dart`
    - _Requirements: 10.3, 11.3, 12.4_
  - [x] 14.2 A+B independence: the `AuthGate` withholds all Wish/account UI while locked regardless of sync; each feature cleanly absent when unconfigured
    - _Requirements: 13.1, 13.2, 13.3_

- [x] 15. Option B tests
  - `sync_merge_test` (9): local-only / remote-only / conflicting edits converge to last-write-wins; delete-vs-edit per tombstone; tie → remote; no duplicate UUIDs. `account_controller_test` (7): sign-up/in success & failure, restore, sign-out keeps local data.
  - _Requirements: 10, 11, 12_

- [x] 16. Full offline-first test + Phase 2 checkpoint
  - Extended `offline_no_backend_test` with offline-first checks: `package:pocketbase` imported only by `data/account/remote/` + `account_providers.dart`; the local graph never imports the account/sync layer; app builds with the remote layer unconfigured. `flutter analyze` clean, `flutter test` 104/104 pass, `flutter build web` succeeds with no backend configured.
  - _Requirements: 14.1, 14.2, 14.3_

### Known follow-up

- Local delete currently hard-deletes; propagating a _local_ delete to other devices needs a local tombstone source (the `SyncController` passes an empty tombstone list today). Remote deletes pulled from the server are applied locally. Documented in `docs/pocketbase/README.md`.

## Notes

- Each auth property is implemented by exactly one property test tagged `// Feature: auth, Property {n}: ...`, placed next to the unit it exercises, mirroring the wishable spec's convention.
- All native plugin usage stays behind interfaces and a conditional-import seam so the web build never pulls in unsupported platform code — the same discipline that keeps `dart:ffi` out of the web target.
- No step introduces a network, account, or server dependency; the local-first guarantee (R8) holds end to end.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1"] },
    { "id": 1, "tasks": ["2.1", "2.2", "2.3", "2.4"] },
    { "id": 2, "tasks": ["3.1", "3.2", "3.3", "4.1"] },
    { "id": 3, "tasks": ["4.2", "4.3", "4.4", "5.1"] },
    { "id": 4, "tasks": ["5.2", "5.3", "6.1", "6.2", "6.3"] },
    { "id": 5, "tasks": ["6.4", "8", "9"] },
    { "id": 6, "tasks": ["7", "10"] },
    { "id": 7, "tasks": ["11.1", "11.2", "11.3"] },
    { "id": 8, "tasks": ["12"] },
    { "id": 9, "tasks": ["13.1", "13.2", "13.3"] },
    { "id": 10, "tasks": ["14.1", "14.2"] },
    { "id": 11, "tasks": ["15", "16"] }
  ]
}
```
