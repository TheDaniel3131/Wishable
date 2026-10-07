# Deploy the Wishable PocketBase backend to Fly.io

This folder deploys a self-hosted [PocketBase](https://pocketbase.io) instance
to [Fly.io](https://fly.io) for Wishable's optional cross-device sync. The app
works fully offline without any of this; a backend is only needed if you want
remote accounts + sync.

The two things that make or break a PocketBase deployment:

1. **A persistent volume** mounted at `/pb/pb_data`. Without it, every deploy or
   restart wipes the database.
2. **Exactly one machine.** PocketBase uses embedded SQLite, which cannot be
   shared across instances. Never scale beyond one machine.

## Files

- `Dockerfile` — Alpine image that downloads PocketBase (version pinned by the
  `PB_VERSION` build arg, matching `/pocketbase/CHANGELOG.md`) and runs
  `pocketbase serve` against the mounted volume.
- `fly.toml` — Fly app config: port 8090, forced HTTPS, a `pb_data` volume
  mount, and single-machine always-on settings.

## Steps

Run these from inside this folder (`deploy/fly/`).

### 1. Install the Fly CLI and sign in

```powershell
pwsh -Command "iwr https://fly.io/install.ps1 -useb | iex"
fly auth login   # or: fly auth signup
```

### 2. Create the app (no deploy yet)

```powershell
fly launch --no-deploy (try this if not work: fly launch --no-deploy --name wishable)
```

Pick an app name and a region. Decline any Postgres/Redis offers. Update the
`app` and `primary_region` values in `fly.toml` to match if `fly launch`
rewrote them.

after that, you can skip to flyctl deploy immediately, skip the rest of the steps.

### 3. Create the persistent volume (same region as the app)

```powershell
fly volumes create pb_data --size 1 --region <your-region>
```

### 4. Deploy

```powershell
fly deploy
fly status
fly open        # opens https://<app>.fly.dev
```

### 5. Create the admin (superuser)

Either open `https://<app>.fly.dev/_/` and complete the setup form, or:

```powershell
fly ssh console -C "/pb/pocketbase superuser create you@example.com YourStrongPassword --dir=/pb/pb_data"
```

Then create the `users` and `wishes` collections and API rules per
`../../docs/pocketbase/README.md`.

### 6. Point the app at your Fly URL

```powershell
flutter build web --dart-define=WISHABLE_PB_URL=https://<app>.fly.dev
```

Or set `WISHABLE_PB_URL` in `.env` so `scripts/run.ps1` / `scripts/run.sh`
forward it automatically.

## Operations

- **Single machine only.** If `fly machine list` shows more than one, destroy
  the extras (`fly machine destroy <id>`).
- **Backups.** All state lives in the volume. Snapshot it with
  `fly volumes snapshots create pb_data`, or pull `pb_data` down via
  `fly ssh sftp`.
- **Logs / memory.** `fly logs` to watch for OOM restarts; bump `memory` in
  `fly.toml` to `512mb` if needed.
- **Version bumps.** Change `PB_VERSION` in the `Dockerfile` (keep it in step
  with `/pocketbase/CHANGELOG.md`) and re-run `fly deploy`.
