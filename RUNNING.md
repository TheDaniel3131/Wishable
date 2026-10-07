# Running Wishable — Setup & Run Cheatsheet

Quick reference for running the Flutter app and the optional PocketBase backend.

- **App:** Flutter (local-first). Works fully offline with no backend.
- **Backend:** PocketBase (optional). Only needed for remote accounts + cross-device sync.

Verified environment: Flutter 3.47.6 (Dart 3.13.5). All platform runner folders
(`android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`) are present.

---

## 1. One-time setup

```sh
flutter pub get        # fetch dependencies
flutter analyze        # optional: static checks
flutter test           # optional: run the test suite
```

If the native runner folders were ever missing, regenerate them (non-destructive
to `lib/`, `pubspec.yaml`, and `.kiro/`):

```sh
flutter create --platforms=web,windows,macos,linux,android,ios --org com.wishable .
flutter pub get
```

---

## 2. Run the Flutter app

### Local-only (no backend, simplest)

```sh
flutter run -d chrome      # web
flutter run -d windows     # Windows desktop
flutter run                # pick a device interactively
```

The app is fully functional offline. The Account & sync screen will simply
report that remote accounts are not configured.

### Connected to the backend (enables sync)

Point the app at your PocketBase server with a compile-time define:

```sh
flutter run -d chrome --dart-define=WISHABLE_PB_URL=http://127.0.0.1:8090
```

For a production build:

```sh
flutter build web --dart-define=WISHABLE_PB_URL=https://your-pocketbase.example.com
```

> The URL is read at compile time. When empty, the remote layer is inert and the
> app stays purely local.

---

## 3. Run the backend (PocketBase) — optional

PocketBase is a single executable. Download the binary for your platform from
the [PocketBase releases page](https://pocketbase.io), then run it.

### Windows (PowerShell)

```powershell
.\pocketbase.exe serve
```

### macOS / Linux

```sh
./pocketbase serve
```

Endpoints:

- Admin UI: `http://127.0.0.1:8090/_/`
- API base: `http://127.0.0.1:8090`

For a real deployment, run the binary on a small VPS / Fly.io / Railway behind
HTTPS. The app only needs the public base URL.

---

## 4. Configure PocketBase collections (first run only)

Open the Admin UI (`http://127.0.0.1:8090/_/`) and create the following. Full
details and field notes live in `docs/pocketbase/README.md`.

### `users` (auth collection — built in)

Enable the auth methods you want:

- **Identity/Password** (email + password) — enough on its own.
- **OAuth2** providers (Google / Apple / GitHub) — optional, add client id/secret.

### `wishes` (new Base collection)

Add these fields (the app's own fields, distinct from PocketBase's auto
`created`/`updated`):

| field           | type                                 | notes                                           |
| --------------- | ------------------------------------ | ----------------------------------------------- |
| `owner`         | Relation → `users`, single, required | the signed-in user                              |
| `wishId`        | Plain text                           | stable Wish UUID (sync identity)                |
| `title`         | Plain text                           |                                                 |
| `description`   | Plain text                           | may be empty                                    |
| `categoryName`  | Plain text                           | category by name                                |
| `priority`      | Select (single)                      | options: `low` / `medium` / `high`              |
| `status`        | Select (single)                      | options: `active` / `in progress` / `completed` |
| `progress`      | Number                               | 0–100                                           |
| `wishCreatedAt` | Datetime                             | device time (NOT Autodate)                      |
| `wishUpdatedAt` | Datetime                             | drives last-write-wins (NOT Autodate)           |
| `wishDeletedAt` | Datetime                             | empty = live; set = soft-delete tombstone       |

Important:

- Status values must be exactly `active`, `in progress`, `completed` (note the
  space). Priority exactly `low`, `medium`, `high`.
- The three timestamps must be **Datetime**, NOT Autodate — Autodate is
  server-managed and would overwrite the device edit time conflict resolution
  depends on.
- A unique index on (`owner`, `wishId`) is recommended (optional but tidy).

### API rules

On the `wishes` collection's **API rules** tab, set List, View, Create, Update,
and Delete all to:

```
@request.auth.id != "" && owner = @request.auth.id
```

This scopes every operation so each user only sees/edits their own Wishes.

### `wish_images` (new Base collection — for image sync)

Only needed if you want attached images to sync. Create a Base collection named
`wish_images` with these fields:

| field          | type                                 | notes                                     |
| -------------- | ------------------------------------ | ----------------------------------------- |
| `owner`        | Relation → `users`, single, required | the signed-in user                        |
| `imageId`      | Plain text                           | stable image UUID (sync identity)         |
| `wishId`       | Plain text                           | the owning Wish's UUID                    |
| `file`         | **File** (single, images)            | the image bytes (Option A storage)        |
| `mimeType`     | Plain text                           | e.g. `image/jpeg`                         |
| `position`     | Number                               | display order                             |
| `imgCreatedAt` | Datetime                             | device creation time                      |
| `imgDeletedAt` | Datetime                             | empty = live; set = soft-delete tombstone |

Set the same API rules as `wishes` (all five to
`@request.auth.id != "" && owner = @request.auth.id`).

Images are stored on the PocketBase server's disk by default. To put them on
S3-compatible storage (AWS S3, Cloudflare R2, etc.) instead, configure
**Settings → Files storage** in the PocketBase admin UI — no app change needed.

---

## 5. Typical workflows

**Just try the app:**

```sh
flutter pub get
flutter run -d chrome
```

**App + sync (two terminals):**

```sh
# Terminal 1 — backend
.\pocketbase.exe serve

# Terminal 2 — app
flutter run -d chrome --dart-define=WISHABLE_PB_URL=http://127.0.0.1:8090
```

Then in the app: Settings → Account & sync → sign in / sign up, and use
"Sync now".

---

## 6. Local notifications (optional)

Wishable schedules **local** notifications only — a periodic "keep going" nudge
and per-wishlist reminders. There is no push server; everything is scheduled
on-device via `flutter_local_notifications` + `timezone`. Enable them in
**Settings → Notifications**, then set a reminder from a wishlist's detail
screen.

Platform support and permission notes:

- **Web:** unsupported by design. The notifications section degrades to a no-op
  (the toggle reports it's unavailable); nothing to configure.
- **Android:** needs the `POST_NOTIFICATIONS` runtime permission on Android 13+
  (API 33). The app requests it when you enable notifications. For exact-time
  reminders on Android 12+ you may also need the "Alarms & reminders" permission
  granted in system settings. These are declared by the plugin; if you
  regenerated the `android/` runner, re-run `flutter pub get` so the manifest
  merge picks them up.
- **iOS / macOS:** the OS prompts for notification permission the first time you
  enable them. Denying it leaves the feature off until granted in system
  settings.
- **Windows / Linux:** no explicit permission grant is required; notifications
  schedule immediately once enabled.

If a platform or the user denies permission, enabling fails gracefully and the
app stays in the disabled state — no crash, no partial scheduling.

## Notes & gotchas

- The local app lock (Option A) and remote account (Option B) are independent:
  unlocking locally does not sign you in, and signing in does not bypass the lock.
- Conflict resolution is last-write-wins by `updatedAtUtc`; the `deletedAtUtc`
  tombstone resolves delete-vs-edit races.
- Local delete currently hard-deletes; full propagation of a local delete to
  other devices is a known follow-up (remote deletes pulled from the server are
  applied locally today).
- OAuth sign-in needs a URL launcher wired at the app entry point; email +
  password works without any OAuth config.
- Reference docs: `README.md` (architecture) and `docs/pocketbase/README.md`
  (backend details).
