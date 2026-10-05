# Wishable

A cross-platform, local-first personal wishlist and achievement tracker, built
from a single Flutter/Dart codebase targeting **web, Windows, macOS, Linux,
Android, and iOS** (requirement 13.1).

## Architecture

Wishable uses a strict four-layer architecture (see
`.kiro/specs/wishable/design.md`). Dependencies point strictly downward and the
data-access layer is the only layer permitted to reference Drift (R14.3).

```
lib/
  presentation/      Flutter widgets, GoRouter, responsive shell, views
  application/       Riverpod providers + controllers (view-models)
  domain/            Pure Dart: models, LifecyclePolicy, validators, serializers
  data/              The ONLY layer touching Drift
    connection/      Conditional-import database opener (native / web / unsupported)
  theme/             Material 3 theme + Material Symbols icon configuration
main.dart            Entry point (ProviderScope + Material 3 MaterialApp)
```

- **Persistence:** Drift over SQLite (`NativeDatabase` on native, `WasmDatabase`
  / OPFS on web).
- **State:** Riverpod. **Navigation:** GoRouter. **UI:** Material 3 + Material
  Symbols icons. **Backup I/O:** `file_picker` + `path_provider`.
- **IDs/time:** every Wish carries a stable UUID and UTC created/updated
  timestamps (R14.1, R14.2).

## Completing the platform scaffold

The Dart source, `pubspec.yaml`, analysis config, and web entry files are
checked in. The native platform runner folders (`android/`, `ios/`, `macos/`,
`windows/`, `linux/`) are large, toolchain-generated trees. Generate them in
place over the existing files with the Flutter SDK:

```sh
flutter create --platforms=web,windows,macos,linux,android,ios --org com.wishable .
flutter pub get
```

`flutter create .` is non-destructive to the existing `lib/`, `pubspec.yaml`,
and the `.kiro/` spec folder — it only fills in missing platform scaffolding.

> Note on this environment: the sandbox shell used to author this scaffold could
> not execute commands (every invocation, including `echo`, returned exit code
> -1), and no Flutter SDK was on `PATH`. The hand-authored files above are
> complete and self-consistent; run the two commands above on a machine with the
> Flutter SDK to generate native runners and fetch packages.

## Verify

```sh
flutter pub get
flutter analyze
flutter test
flutter build web   # or: flutter build windows / apk / ...
```

## Custom Kiro agents

Workspace agents live under `.kiro/agents/` (IDE 1.0 Markdown format). Each is
tailored to this Flutter/Drift/Riverpod codebase and can be selected from Kiro's
agent picker:

| Agent                       | Focus                                                                 |
| --------------------------- | --------------------------------------------------------------------- |
| `flutter-buddy`             | Flutter/Dart implementation — widgets, Riverpod, GoRouter, Material 3 |
| `code-reviewer`             | Correctness, layering, security, performance, readability review      |
| `devops-buddy`              | Builds, CI/CD, release, packaging across all six targets              |
| `database-expert`           | Drift schema, migrations, reactive queries, backup/restore            |
| `debug-detective`           | Systematic reproduce → isolate → root-cause → verified fix            |
| `architecture-reviewer`     | Guards the four-layer architecture and local-first invariant          |
| `senior-software-engineer`  | Generalist, end-to-end feature/bug delivery                           |
| `test-engineer`             | Unit, property, widget, integration tests mapped to requirements      |
| `security-auditor`          | Local data protection and the auth/app-lock feature                   |
| `ux-accessibility-reviewer` | Material 3 usage, responsive behavior, accessibility                  |

## Specs

Feature specs live under `.kiro/specs/`:

- `wishable/` — the core app spec (requirements, design, tasks). The tasks file
  also records post-completion bug fixes (web-build `dart:ffi` leak, placeholder
  font, missing create button) in its "Post-completion fixes" section.
- `auth/` — **Authentication**. Two layers, both in scope:
  - **Option A — local app lock** (passcode/PIN + biometric unlock, lockout
    backoff, auto-lock on background): **implemented**. Pure domain
    (`domain/auth/`), secure storage via `flutter_secure_storage`
    (`data/auth/`), `AuthController` (`application/auth/`), and the `AuthGate` +
    `LockScreen` + `PasscodeSetupView` (`presentation/auth/`). Set it up under
    Settings → Security. 34 tests cover it.
  - **Option B — remote accounts + sync** (email/OAuth sign-in, cross-device
    sync with last-write-wins by `updatedAtUtc`): **implemented** against a
    self-hosted **PocketBase** backend (both auth methods). Domain
    (`domain/account/`), the backend-agnostic interfaces + PocketBase adapter
    (`data/account/`, SDK confined to `data/account/remote/`), the
    `AccountController` + `SyncController` (`application/account/`), and the
    account/sync UI (`presentation/account/`). The core invariant is
    **offline-first with optional sync**: the app works fully offline with no
    account, and the remote layer is inert until configured + signed in. Setup:
    `docs/pocketbase/README.md`. Enable with
    `--dart-define=WISHABLE_PB_URL=<your-server>`.

  Notes:
  - `flutter_secure_storage` / `local_auth` are confined to `data/auth/`, and
    the `pocketbase` SDK to `data/account/remote/` (+ one composition-root
    provider). They never leak into other layers — enforced by the data-access
    boundary and offline-first architecture tests.
  - Local delete currently hard-deletes; propagating a local delete to other
    devices is a documented follow-up (remote deletes are applied locally).
