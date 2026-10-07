# Wishable — Technical Report

## 1. Overview

Wishable is a **cross-platform, local-first personal wishlist and achievement tracker**. It is built from a single Flutter/Dart codebase and targets six platforms: **web, Windows, macOS, Linux, Android, and iOS**.

The defining product principle is **offline-first with optional sync**: the app is fully functional with no backend and no account. A self-hosted remote backend (PocketBase) can optionally be enabled for cross-device sync, but the remote layer stays completely inert until it is both configured at build time and signed into at runtime.

Current version: `0.1.0+1`. A `LICENSE` is present. The project is not published to pub (`publish_to: none`).

## 2. Tech Stack at a Glance

| Concern | Technology |
|---|---|
| Language | Dart (SDK `>=3.4.0 <4.0.0`) |
| UI framework | Flutter (`>=3.22.0`), Material 3 |
| State management | Riverpod (`flutter_riverpod` / `riverpod` ^2.5.1) |
| Navigation | GoRouter (`go_router` ^14.2.0) |
| Local persistence | Drift ORM over SQLite |
| Web persistence | Drift `WasmDatabase` over OPFS (fallback IndexedDB) |
| Remote backend (optional) | PocketBase (self-hosted) |
| Icons | Material Symbols (bundled variable font) |
| Testing | `flutter_test` + `glados` (property-based) |
| Codegen | `drift_dev` + `build_runner` |
| Linting | `flutter_lints` with strict casts/raw types |

## 3. Dependencies

### Runtime dependencies
- **Persistence:** `drift` ^2.20.0, `sqlite3` ^2.4.6, `sqlite3_flutter_libs` ^0.5.20 (bundles SQLite natively), `drift_flutter` ^0.2.0, `web` ^1.1.0 (Drift WASM/OPFS on web).
- **State:** `flutter_riverpod` / `riverpod` ^2.5.1.
- **Navigation:** `go_router` ^14.2.0.
- **File I/O (backup/restore):** `file_picker` ^8.0.6, `path_provider` ^2.1.3, `path` ^1.9.0.
- **Identifiers:** `uuid` ^4.4.0 (stable UUID per Wish).
- **Authentication / app lock:** `flutter_secure_storage` ^9.2.2 (Keychain/Keystore), `local_auth` ^2.3.0 (Touch ID / Face ID / Windows Hello), `crypto` ^3.0.5 (PBKDF2/HMAC for passcode verifier).
- **Optional remote accounts + sync:** `pocketbase` ^0.22.0 (official Dart SDK), `connectivity_plus` ^6.0.5 (sync only when online), `http` ^1.2.0 (image download in the remote adapter).
- **Local notifications:** `flutter_local_notifications` ^18.0.1, `timezone` ^0.9.4 (zoned scheduling).
- **Misc:** `cupertino_icons` ^1.0.8.

### Dev dependencies
- `drift_dev` ^2.20.0 + `build_runner` ^2.4.11 (Drift code generation)
- `glados` ^1.1.6 (property-based testing)
- `flutter_lints` ^4.0.0
- `flutter_test` (SDK)

## 4. Architecture

Wishable enforces a **strict four-layer architecture** with dependencies pointing strictly downward. The data-access layer is the only layer permitted to touch Drift.

```
lib/
  presentation/   Flutter widgets, GoRouter, responsive shell, views
  application/    Riverpod providers + controllers (view-models)
  domain/         Pure Dart: models, policies, validators, serializers
  data/           The ONLY layer touching Drift
  theme/          Material 3 theme + Material Symbols config
  main.dart       Entry point (ProviderScope + MaterialApp.router)
```

**Presentation** (`lib/presentation/`): `account/`, `auth/`, `brand/` (splash), `overlay/` (celebration listener), `router/` (GoRouter config), `shell/` (responsive navigation shell), `views/` (wish list / detail / edit forms). The root `main.dart` wires a `ProviderScope` → `MaterialApp.router`, with a branded startup splash, an auto-lock observer, and a completion-celebration overlay layered via the router's `builder`.

**Application** (`lib/application/`): Riverpod providers and controllers acting as view-models — `account/`, `auth/`, `controllers/`.

**Domain** (`lib/domain/`): pure Dart with no framework imports — `Wish`, `Category`, `Priority`, the lifecycle model (`LifecyclePolicy`, `LifecycleStatus`, `LifecycleEvent`), validators (`wish_validator.dart`), serializers (`wish_json_codec.dart`, `wish_csv_codec.dart`), `AppSettings`, backup and notification models, and stable ID generation.

**Data** (`lib/data/`): the only Drift-aware layer. `app_database.dart` + generated `app_database.g.dart`, `tables.dart`, `repositories/`, plus three strictly isolated native-dependency seams:
- `connection/` — conditional-import database opener with native (`native.dart`), web (`web.dart`), and `unsupported.dart` variants, so native `dart:ffi`/`sqlite3` never leak into the web build.
- `auth/` — confines `flutter_secure_storage` and `local_auth`.
- `account/remote/` — confines the `pocketbase` SDK (includes `pocketbase_client.dart` and `pocketbase_sync_service.dart`).
- `notify/` — confines `flutter_local_notifications` behind a conditional-import seam (web is a graceful no-op).

### Key invariants
- Every Wish carries a stable UUID plus UTC created/updated timestamps.
- Cross-device sync uses **last-write-wins by `updatedAtUtc`**.
- Native-only packages (`flutter_secure_storage`, `local_auth`, `pocketbase`, `flutter_local_notifications`) are confined to their data-layer seams and never leak upward. This boundary is enforced by **architecture tests**.

## 5. Features

- **Wishlist management:** create/edit/delete Wishes with categories, priorities, and a lifecycle (status + events) model.
- **Achievement tracking:** lifecycle transitions with completion celebrations (overlay).
- **Backup / restore:** export/import via `file_picker` + `path_provider`; JSON and CSV codecs in the domain layer.
- **Authentication (two independent layers, both implemented):**
  - *Option A — local app lock:* passcode/PIN + biometric unlock, lockout backoff, auto-lock on background. Pure domain logic with secure storage; ~34 tests cover it.
  - *Option B — remote accounts + sync:* email/OAuth sign-in against self-hosted PocketBase, with offline-first sync (last-write-wins). Inert until `WISHABLE_PB_URL` is set and the user signs in.
- **Local notifications:** scheduled reminders and periodic nudges on supported platforms; no-op on web.
- **Responsive Material 3 UI** with a navigation shell and system light/dark theming.

## 6. Build, Config & Tooling

- **Configuration** is compile-time via `--dart-define` (`String.fromEnvironment`). A gitignored `.env` (template `.env.example`) holds `WISHABLE_PB_URL`; helper scripts `scripts/run.ps1` (Windows) and `scripts/run.sh` (macOS/Linux/CI) forward it into the build. An empty URL → purely local/offline.
- **Codegen:** `dart run build_runner build` regenerates Drift code when the schema changes.
- **Linting:** `flutter_lints` base plus `strict-casts` and `strict-raw-types`; extra rules include `prefer_const_constructors`, `prefer_final_locals`, `avoid_print`, `directives_ordering`. Generated `*.g.dart` and platform folders are excluded from analysis.
- **Native runners:** `android/`, `ios/`, `macos/`, `windows/`, `linux/`, `web/` are all present. Release build commands per platform are documented in `BUILD.md`.
- **Web specifics:** ships `sqlite3.wasm` + `drift_worker.js`; needs the `application/wasm` MIME type and prefers cross-origin isolation for OPFS.
- **Optional backend:** PocketBase binary with `users` + `wishes` collections and API rules; schema/setup in `docs/pocketbase/README.md`. The web build can be served from PocketBase's `pb_public/` to share one origin and sidestep CORS.

## 7. Testing

Testing is organized to mirror the architecture, under `test/`: `domain/`, `application/`, `data/`, `presentation/`, and a dedicated `architecture/` suite plus `widget_test.dart`. **35 test files** total. The suite combines example-based `flutter_test` with **property-based tests via `glados`**. The architecture tests specifically guard the four-layer boundaries and the offline-first invariant (ensuring native/remote packages don't leak out of their data-layer seams).

## 8. Documentation & Project Meta

- `README.md` — architecture overview, scaffold completion, agent catalog, specs.
- `BUILD.md` — production build/release guide per platform.
- `RUNNING.md` — day-to-day local running.
- `docs/pocketbase/README.md` — optional backend schema/setup.
- `.kiro/specs/` — formal feature specs (`wishable/` core app, `auth/` authentication) with requirements/design/tasks.
- `.kiro/agents/` — ten custom Kiro workspace agents tailored to this Flutter/Drift/Riverpod codebase (e.g. `flutter-buddy`, `database-expert`, `architecture-reviewer`, `security-auditor`).

---

*This report is based on direct inspection of `pubspec.yaml`, `README.md`, `BUILD.md`, `analysis_options.yaml`, `main.dart`, and the `lib/`, `test/`, `scripts/`, and `docs/` directory structures. It does not reflect a live `flutter analyze`/`flutter test` run; stated test behavior reflects the code structure and docs.*
