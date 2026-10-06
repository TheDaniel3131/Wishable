# PocketBase backend for Wishable (optional sync)

Wishable works fully offline with no account. Remote accounts and cross-device
sync (auth spec, Option B) are **optional** and backed by a self-hosted
[PocketBase](https://pocketbase.io) server. If you never configure a backend,
the app ignores all of this and stays local-only.

## 1. Run a PocketBase server

PocketBase is a single executable. Download the binary for your platform from
the PocketBase releases page, then run it:

```sh
./pocketbase serve
# Admin UI: http://127.0.0.1:8090/_/
# API base: http://127.0.0.1:8090
```

For a real deployment, run the binary on a small VPS / Fly.io / Railway and put
it behind HTTPS. The app only needs the public base URL.

## 2. Configure collections

Open the Admin UI and create the following, matching what the adapter expects
(`lib/data/account/remote/pocketbase_sync_service.dart`).

### `users` (auth collection — built in)

Enable the auth methods you want (the app supports both):

- **Identity/Password** (email + password).
- **OAuth2** providers (Google / Apple / GitHub) — add the client id/secret for
  each in the Admin UI.

### `wishes` (base collection)

Create a new **Base** collection named `wishes`. Add the fields below with
"New field". These are the app's OWN fields, named distinctly from PocketBase's
auto `created` / `updated` system fields so they never collide.

> On PocketBase 0.23+ the create dialog may pre-add Autodate fields named
> `createdAt` / `updatedAt` / `deletedAt`. You can leave them or delete them —
> the app does NOT use them. The app uses its own `wishUpdatedAt` as the source
> of truth for conflict resolution (the device edit time, not the server
> receive time), which is why these are plain-text fields the app writes.

| field           | field type                               | notes                                           |
| --------------- | ---------------------------------------- | ----------------------------------------------- |
| `owner`         | **Relation** → `users`, single, required | the signed-in user                              |
| `wishId`        | **Plain text**                           | the stable Wish UUID (sync identity)            |
| `title`         | **Plain text**                           |                                                 |
| `description`   | **Plain text**                           | may be empty                                    |
| `categoryName`  | **Plain text**                           | category by name (resolved locally)             |
| `priority`      | **Select** (single)                      | options: `low` / `medium` / `high`              |
| `status`        | **Select** (single)                      | options: `active` / `in progress` / `completed` |
| `progress`      | **Number**                               | 0–100                                           |
| `wishCreatedAt` | **Datetime**                             | the app writes this (device time)               |
| `wishUpdatedAt` | **Datetime**                             | drives last-write-wins conflict resolution      |
| `wishDeletedAt` | **Datetime**                             | empty = live; set = soft-delete tombstone       |

> Status option values must be exactly `active`, `in progress`, `completed`
> (note the space in "in progress") and priority exactly `low`, `medium`,
> `high`. The app maps its internal enum to these tokens. The three timestamps
> must be **Datetime**, NOT Autodate — Autodate is server-managed and would
> overwrite the device edit time that conflict resolution depends on.

**API rules** — open the collection's **API rules** tab and set the List, View,
Create, Update, and Delete rules all to:

```
@request.auth.id != "" && owner = @request.auth.id
```

This scopes every operation so each signed-in user only sees and edits their own
Wishes.

A unique index on (`owner`, `wishId`) is recommended to prevent duplicate
records for the same Wish (optional but tidy).

### `wish_images` (optional — for image sync)

If you want attached images to sync across devices, create a Base collection
`wish_images` with: `owner` (Relation → users, required), `imageId` (text),
`wishId` (text), `file` (File field, single, image types), `mimeType` (text),
`position` (number), `imgCreatedAt` (Datetime), `imgDeletedAt` (Datetime,
nullable tombstone). Set all five API rules to
`@request.auth.id != "" && owner = @request.auth.id`.

Images are kept in PocketBase's own file storage (Option A). To offload them to
S3-compatible storage (AWS S3 / Cloudflare R2 / MinIO), flip the **Settings →
Files storage** toggle in the admin UI — the app code is unchanged.

### OAuth (optional — skip for now)

Email + password alone is enough. The app shows OAuth buttons, but you can
ignore them until you decide to configure providers in the `users` collection's
OAuth2 settings. Nothing breaks with OAuth left unconfigured.

## 3. Point the app at your server

The backend URL is read from a compile-time define
(`lib/data/account/remote/pocketbase_client.dart`). When it is empty, the remote
layer is inert and the app is purely local.

```sh
flutter run -d chrome --dart-define=WISHABLE_PB_URL=http://127.0.0.1:8090
# or for a build:
flutter build web --dart-define=WISHABLE_PB_URL=https://your-pocketbase.example.com
```

With the URL set, Settings → Account & sync offers sign-in / sign-up (email or
OAuth) and a "Sync now" action. Without it, that screen reports that remote
accounts are not configured, and everything else works offline as before.

## Notes & limitations

- The local app lock (Option A) and the account (Option B) are independent:
  unlocking locally does not sign you in, and signing in does not bypass the
  lock.
- Conflict resolution is last-write-wins by `updatedAtUtc`, with the
  `deletedAtUtc` tombstone resolving a delete-vs-edit race.
- Local delete currently hard-deletes; full propagation of a local delete to
  other devices (via a local tombstone) is a known follow-up — remote deletes
  pulled from the server are applied locally today.
- OAuth sign-in needs a URL launcher wired at the app entry point; the data
  layer stays plugin-free by accepting an injected launcher.
