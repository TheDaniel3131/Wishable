# Design: Authentication / App Lock

## Overview

This feature adds a **local app lock** to Wishable: an optional passcode (PIN/password) plus biometric gate shown before the app content, protecting on-device data without any account, server, or network call. It slots into the existing four-layer architecture and preserves the local-first invariant (wishable R10.2, R10.3) — the offline/no-backend architecture test must still pass.

The lock is modeled as a pure state machine (`AuthState`), a pure policy/verifier (hashing, comparison, lockout), a data layer that persists only a non-reversible verifier in the platform secure store, a Riverpod controller, and a presentation gate that wraps the router.

Both layers are in scope (product-owner decision):

- **Option A — local app lock** (sections below through "Testing strategy"): built first; self-contained; no network.
- **Option B — remote accounts + sync** (section "Option B: remote accounts + sync"): layered on top, reusing the same `AuthController`/provider surface; gated on a backend choice (Supabase / Firebase / custom) and an auth-method choice.

The original "no backend compiled in" rule is replaced by **offline-first with optional sync**: the local app (Wishes + local lock) must not depend on the remote layer, and must build and run with the remote layer unconfigured. The remote layer is inert while signed out.

## Architecture

Follows the existing module boundaries. New code is placed by layer:

```
lib/
  domain/auth/
    auth_state.dart          # sealed AuthState: Unconfigured | Locked | Unlocked | CoolingDown
    passcode_policy.dart     # pure validation (PIN >= 4 digits / password >= 6 chars)
    passcode_hasher.dart     # pure KDF verifier: hash(passcode, salt) -> verifier; constant-time verify
    lockout_policy.dart      # pure: attempts + timestamps -> allowed? / remaining cooldown (backoff)
    auth_credentials.dart    # value type: verifier bytes, salt, kdf params, biometricEnabled, lockTimeout
  data/auth/
    auth_store.dart          # abstract interface: read/write/clear AuthCredentials + failure state
    secure_auth_store.dart   # flutter_secure_storage-backed implementation (native) ...
    connection/              # conditional-import seam for secure storage availability (web fallback)
    biometric_authenticator.dart  # abstract interface over local_auth
  application/auth/
    auth_controller.dart     # Notifier<AuthState>: enroll / unlock / unlockBiometric / change / disable / lock
    auth_providers.dart      # providers for store, hasher, biometric, controller (interface-typed)
  presentation/auth/
    lock_screen.dart         # the lock UI (passcode entry + biometric button + cooldown)
    auth_gate.dart           # wraps the app: shows LockScreen when Locked, app when Unlocked
    passcode_setup_view.dart # enroll / change / disable flows (in Settings)
```

- `domain/auth` is pure Dart — no Flutter, no Drift, no `dart:io`, no plugins. The hasher, policy, and lockout are deterministic and injectable, so they are unit- and property-testable.
- `data/auth` is the only place that touches platform plugins (`flutter_secure_storage`, `local_auth`) and any native API. Secure-storage availability is handled behind a conditional-import seam exactly like `data/connection/`, so web (which lacks a native secure store) falls back without dragging unsupported code into other targets.
- `application/auth` exposes the controller and providers typed to **interfaces** (`AuthStore`, `PasscodeHasher`, `BiometricAuthenticator`), so the presentation layer never sees a plugin or platform type.
- `presentation/auth` renders the gate and screens using the interface-typed providers only.

## Dependencies (new)

- `flutter_secure_storage` — Keychain/Keystore-backed secure key/value store for the verifier, salt, KDF params, and flags (R7). Pinned version.
- `local_auth` — platform biometric prompt (R3). Pinned version.
- `crypto` (or `cryptography`) — the KDF/hash primitive for the passcode verifier (R1.5, R7). Prefer a slow KDF (PBKDF2 with a high iteration count, or Argon2 via `cryptography`). Pinned version.

All three are widely used, actively maintained packages. None introduces a network/account dependency, so the local-first invariant and its architecture test hold (R8).

> Note: on **web**, `flutter_secure_storage` degrades (browser storage, weaker guarantees) and `local_auth` biometric support is limited. The design handles both via graceful degradation (R3.4, R7.2) and the UI states the reduced protection (R9.2).

## Data Models

### `AuthState` (sealed)

```
sealed class AuthState
  AuthUnconfigured   // no passcode enrolled; app is always unlocked (R1.1)
  AuthLocked         // enrolled, waiting for authentication (R2.1)
  AuthUnlocked       // authenticated this session (R2.2)
  AuthCoolingDown(remaining) // too many failures; wait before retry (R4.2)
```

### `PasscodePolicy` (pure)

`validate(PasscodeInput) -> PolicyResult` enforcing kind-specific minimums (R1.4). Rejects mismatched confirmation at the controller level (R1.3).

### `PasscodeHasher` (pure, injectable)

- `AuthCredentials enroll(String passcode)` → generates a random salt, derives the verifier with the KDF, returns credentials carrying salt + KDF params (never the passcode) (R1.5).
- `bool verify(String passcode, AuthCredentials creds)` → re-derives and compares in **constant time** (R2.4). KDF cost is a tunable parameter chosen for acceptable unlock latency.

### `LockoutPolicy` (pure)

Given the failed-attempt count and last-failure timestamp, returns whether an attempt is allowed and, if not, the remaining cooldown, applying backoff after the threshold (R4.1–R4.3). Deterministic given an injected clock, so it is testable without real time.

## Components and Interfaces

### Data layer

#### `AuthStore` (interface)

```
Future<AuthCredentials?> read();        // null => unconfigured
Future<void> write(AuthCredentials c);  // enroll / change
Future<void> clear();                   // disable (R5.2)
Future<AuthFailureState> readFailures();
Future<void> writeFailures(AuthFailureState s);
```

`SecureAuthStore` implements it over `flutter_secure_storage`. The stored payload is the verifier bytes, salt, KDF params, `biometricEnabled`, and `lockTimeout` — **never** the passcode (R7.1). A conditional-import seam provides the web fallback (R7.2). Nothing auth-related is written to the Drift database in cleartext.

#### `BiometricAuthenticator` (interface)

```
Future<bool> isAvailable();
Future<bool> authenticate(String reason);
```

Implemented over `local_auth`; returns `false` for unavailable/failed/cancelled so the controller falls back to passcode (R3.3, R3.4).

### Application layer

#### `AuthController extends Notifier<AuthState>`

- `build()` reads the store: no credentials → `AuthUnconfigured` (app usable, R1.1); credentials present → `AuthLocked` (R2.1, R6.2).
- `enroll(passcode, confirm, {kind})` → policy-validate, confirm match, hash, persist, move to `AuthUnlocked` (R1).
- `unlock(passcode)` → lockout check → `verify` → on success reset failures and go `AuthUnlocked` (R2.2, R4.3); on failure increment failures, apply backoff, stay `AuthLocked`/`AuthCoolingDown` with a non-revealing error (R2.3, R4).
- `unlockBiometric()` → if available and enabled, prompt; success → `AuthUnlocked`; otherwise remain locked for passcode (R3).
- `changePasscode(current, next, confirm)` → authenticate with current (or biometric), then enroll next (R5.1).
- `disable(current)` → authenticate, then `clear()` and go `AuthUnconfigured` (R5.2).
- `lock()` → from `AuthUnlocked` back to `AuthLocked`, invoked by the lifecycle/timeout observer (R6).

All methods perform no network I/O (R8.1).

#### Auto-lock

An app-lifecycle observer (`WidgetsBindingObserver` / focus listener) calls `AuthController.lock()` when the app has been backgrounded/unfocused beyond `lockTimeout` (R6.1), and the controller starts `AuthLocked` on cold start when enrolled (R6.2).

### Presentation layer

#### `AuthGate`

Wraps the app at the root (inside `ProviderScope`, around `MaterialApp.router`). It watches `AuthState`:

- `AuthUnconfigured` or `AuthUnlocked` → render the normal app (the GoRouter shell).
- `AuthLocked` / `AuthCoolingDown` → render `LockScreen`, and do not build the Wish UI (R2.1).

This keeps the lock orthogonal to the existing router — no route changes needed to protect content.

#### `LockScreen`

Passcode entry (numeric keypad for PIN, obscured text field for password), a biometric button when available/enabled (R3.1), inline non-revealing errors (R2.3), and a cooldown indicator with remaining time when `AuthCoolingDown` (R4.2). Accessible: labelled inputs and biometric control, large-text friendly.

#### `PasscodeSetupView` (in Settings)

Enroll, change, and disable flows (R1, R5), plus toggles for biometric unlock, auto-lock timeout, and (if offered) database encryption. When encryption is not implemented, the screen states the lock protects UI access only, not data at rest (R9.2).

## Data-at-rest (R9) — scoped decision

This iteration implements the **UI access gate** and clearly labels that it protects access, not data at rest (R9.2), unless the product owner opts into database encryption. If encryption is chosen, the DB key derives from the passcode via the KDF and the connection opener requires it; passcode change re-keys atomically (R9.1, R9.3). This is isolated to `data/connection/` so it does not ripple through the app. **Decision deferred to the product owner.**

## Correctness Properties

Each property is implemented by exactly one property-based test, tagged
`// Feature: auth, Property {n}: ...`, next to the unit it exercises.

### Property 1: Passcode verifier round-trip

For any valid passcode, `verify(passcode, enroll(passcode))` is true, and
`verify(other, enroll(passcode))` is false.

**Validates: Requirements 1.5, 2.4**

### Property 2: Lockout backoff monotonicity

For consecutive failures at or beyond the threshold, the required cooldown is
non-decreasing and capped, and a successful unlock resets it.

**Validates: Requirements 4.1, 4.3**

### Property 3: Sync convergence (Option B)

Local-only, remote-only, and conflicting edits converge to last-write-wins by
`updatedAtUtc`; delete-vs-edit resolves deterministically via the tombstone; the
same UUID never duplicates.

**Validates: Requirements 12.2, 12.5**

## Error handling

- Wrong passcode / biometric failure → stay locked, generic message, no secret leakage (R2.3, R7.3).
- Secure-store read/write failure → surface a descriptive, secret-free error; never fall back to plaintext storage.
- KDF/verify never logs the passcode, verifier, or salt (R7.3).

## Testing strategy

Pure, injectable units make most of this testable without a device.

- **Property — passcode verifier round-trip**: for any valid passcode, `verify(passcode, enroll(passcode))` is true, and `verify(other, enroll(passcode))` is false. Tag `// Feature: auth, Property 1: ...`.
- **Property — constant-time verify** (structural): verify uses a constant-time comparator (asserted via the comparator API, not timing).
- **Property — lockout backoff monotonicity**: given increasing consecutive failures past the threshold, the required cooldown is non-decreasing; a success resets it. Tag `// Feature: auth, Property 2: ...`.
- **Policy tests**: PIN/password minimums; mismatch rejection; no state change on invalid enroll.
- **Controller tests** (fake `AuthStore` / `BiometricAuthenticator` / injected clock): unconfigured→usable; enroll→unlocked; unlock success/failure transitions; cooldown; biometric fallback; change requires current; disable clears and returns to unconfigured; lock() re-locks.
- **Secure-store test**: write→read round-trips credentials; stored payload contains no plaintext passcode; `clear()` removes everything.
- **Widget tests**: `AuthGate` hides Wish UI while `AuthLocked` and reveals it when `AuthUnlocked`; `LockScreen` shows biometric only when available; cooldown shows remaining time; `PasscodeSetupView` enroll/change/disable happy paths and validation errors.
- **Architecture/offline test (must stay green)**: no `presentation/`/`application/` import of plugins or Drift; `presentation`/`application` auth files do not import `flutter_secure_storage`, `local_auth`, or `package:drift/...`. For Option B, the test becomes the **offline-first** check (see Option B below): the local Wishes + local-lock graph must not import the remote sync/account layer.

---

## Option B: remote accounts + sync

> Gated on two product-owner choices before network code is written: **backend** (Supabase / Firebase / custom) and **auth method** (email-password / OAuth / both). The design keeps the choice confined to one adapter.

### Principle: offline-first, remote layer isolated and optional

The local app (Wishes CRUD + local lock) continues to be the source of truth on-device and works with no network. The remote layer is an **optional, isolated module** that: (1) authenticates an account, and (2) syncs the local Drift database with the backend. It is inert while signed out, and the local graph must not depend on it (enforced by the offline-first test).

### Layering (new code)

```
lib/
  domain/account/
    account.dart            # value type: user id, email, display name (no secrets)
    account_session.dart    # sealed: SignedOut | SignedIn(Account) | SessionError
    sync_state.dart         # sealed: Idle | Syncing | SyncError(message) | Offline
  data/account/
    account_auth_service.dart   # abstract interface: signUp/signIn/signOut/currentSession/restore
    sync_service.dart           # abstract interface: push(localChanges)/pull()/fullReconcile()
    remote/                     # the ONE backend adapter (choice-specific), behind the interfaces
      <backend>_auth_service.dart   # e.g. supabase_auth_service.dart
      <backend>_sync_service.dart
    session_store.dart          # tokens in flutter_secure_storage (reuses the secure-store seam)
  application/account/
    account_controller.dart     # Notifier<AccountSession>: sign-up/in/out, session restore/refresh
    sync_controller.dart        # drives SyncService; exposes SyncState; connectivity-aware
    account_providers.dart      # interface-typed providers; the remote adapter is bound here only
  presentation/account/
    account_view.dart           # sign-in / sign-up / account status in Settings
    sync_status_indicator.dart  # small Syncing/Offline/Error affordance
```

- `domain/account` is pure: identity and session/sync state types, no secrets, no plugins.
- `data/account` holds the interfaces and the single backend adapter under `remote/`. Only this adapter imports the backend SDK (`supabase_flutter` / `firebase_auth`+`cloud_firestore` / an HTTP client for custom). Swapping backends swaps the adapter, nothing else.
- `application/account` exposes interface-typed providers; the concrete adapter is bound only inside provider bodies, mirroring how the Drift repositories are wired.
- `presentation/account` renders sign-in and sync status, using interface-typed providers only.

### Backend adapter (the gated choice)

The interfaces `AccountAuthService` and `SyncService` are backend-agnostic:

```
abstract interface class AccountAuthService {
  Future<AccountSession> signUpEmail(String email, String password);   // if email method enabled
  Future<AccountSession> signInEmail(String email, String password);   // if email method enabled
  Future<AccountSession> signInOAuth(OAuthProvider provider);          // if OAuth enabled
  Future<void> signOut();
  Future<AccountSession> restore();                                     // from persisted tokens
  Stream<AccountSession> sessionChanges();
}

abstract interface class SyncService {
  Future<void> pushLocalChanges(List<Wish> changed);
  Future<List<Wish>> pullRemoteChanges(DateTime since);
  Future<void> fullReconcile();   // on first sign-in / sign-in-again
}
```

**Chosen backend: PocketBase** (product-owner decision). PocketBase is a single open-source Go binary bundling an embedded SQLite database, built-in auth (email/password + OAuth2), realtime subscriptions, and a REST API — a natural fit for a SQLite-shaped app, free, and self-hosted (run the binary on a VPS / Fly.io / Railway / locally). **Auth method: both** email/password and OAuth2.

The adapter uses the official `pocketbase` Dart SDK:

- `PocketBase(baseUrl)` client; `pb.collection('users').authWithPassword(email, pass)` and `pb.collection('users').authWithOAuth2(provider, urlCallback)` for the two auth methods.
- `pb.authStore` holds the session token/record; `authStore.onChange` streams session changes; `authRefresh()` refreshes the token. The token is persisted via our secure-store seam (not PocketBase's default store) so it lives in `flutter_secure_storage`.
- Wishes sync against a `wishes` collection scoped to the authenticated user (an `owner` relation + collection API rules so each user reads/writes only their own records); `getFullList`/`getList(filter: 'updated >= ...')` to pull, `create`/`update`/`delete` to push.

PocketBase requires a running server. The adapter reads its base URL from configuration; when unset/unreachable the app stays in the signed-out, offline-first state and never blocks local use (R14). A `docs/pocketbase/` note will describe running the binary and the `users` + `wishes` collection schema.

### Sync model & conflict resolution

- **Identity**: the Wish UUID is the primary key both locally and remotely, so the same Wish never duplicates across devices (R12.5).
- **Change tracking**: `updatedAtUtc` already exists on every Wish. Sync pulls remote rows changed since the last successful pull watermark and pushes local rows changed since the last push.
- **Conflict resolution**: **last-write-wins by `updatedAtUtc`** (R12.2). Delete vs. edit uses an explicit rule — a tombstone (soft-delete marker with its own `updatedAtUtc`) so a delete can win or lose against a concurrent edit deterministically. (A `deletedAtUtc` nullable column or a `tombstones` table is added via a Drift migration; this is the one schema change Option B needs, and it is append-only and backward-compatible.)
- **Transactionality**: a pull applies into the local DB inside a single Drift transaction so a failed sync leaves local data consistent (R12.4), reusing the same discipline as backup/restore.
- **Offline queue**: while offline, changes accumulate locally (they already persist); on reconnect, `SyncController` pushes then pulls. Connectivity is observed (e.g. `connectivity_plus`) so sync is attempted only when online (R12.3).

### A + B interaction

Independent (R13): `AuthGate` (local lock) gates UI rendering; `AccountController` governs sync. Sync may run while locked, but `AuthGate` still withholds Wish content until unlocked (R13.2). Each feature is cleanly absent when not configured (R13.3).

### Session & token storage

Session tokens persist in `flutter_secure_storage` via the same secure-store seam as the passcode verifier (R11.1); never plaintext, never in the Drift DB. Refresh is transparent while a refresh token is valid (R11.2); irrecoverable refresh failure returns to signed-out (R11.4).

### Testing strategy (Option B)

- **Account controller** (fake `AccountAuthService`): sign-up/in success and failure; session restore from stored tokens; transparent refresh; sign-out clears tokens but keeps local Wishes; offline sign-in with a valid session grants local access (R10, R11).
- **Sync convergence** (fake `SyncService` + in-memory Drift): local-only, remote-only, and conflicting edits converge to last-write-wins by `updatedAtUtc`; delete-vs-edit resolves per the tombstone rule; no duplicate UUIDs after sign-out/sign-in (R12).
- **Sync safety**: a failing pull leaves the local DB unchanged (transactional); offline queues and later converges (R12.3, R12.4).
- **Offline-first architecture test (replaces the old no-backend test)**: the local Wishes + local-lock graph does not import `data/account/**` or any backend SDK; the app builds with the remote layer unconfigured; signed-out means no network (R14).
- **A+B independence**: `AuthGate` withholds content while locked even when a sync is running (R13.2).
