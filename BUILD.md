# Building & Shipping Wishable to Production

This is the release/production guide. For day-to-day local running see
`RUNNING.md`; for the optional backend schema see `docs/pocketbase/README.md`.

Wishable ships from one Flutter/Dart codebase to **web, Windows, macOS, Linux,
Android, and iOS**. It is offline-first: it works with no backend. Remote
accounts + sync (PocketBase) are optional and enabled per build via config.

---

## 1. Prerequisites

- Flutter SDK (stable) with the targets you intend to ship enabled
  (`flutter doctor` should be clean for those platforms).
- Platform toolchains for native targets:
  - **Windows**: Visual Studio with the "Desktop development with C++" workload.
  - **macOS / iOS**: Xcode + CocoaPods.
  - **Android**: Android SDK + a signing keystore.
  - **Linux**: `clang`, `cmake`, `ninja-build`, `pkg-config`, GTK dev headers.
- If the native runner folders are missing, generate them (non-destructive):
  ```sh
  flutter create --platforms=web,windows,macos,linux,android,ios --org com.wishable .
  ```

---

## 2. Configuration (.env → --dart-define)

Flutter resolves `String.fromEnvironment` at **compile time**, so configuration
must be passed as `--dart-define` when you build. To avoid retyping it, Wishable
reads a gitignored `.env` and forwards each value automatically.

1. Copy the template and set your values:
   ```sh
   cp .env.example .env
   ```
   ```ini
   # .env
   WISHABLE_PB_URL=https://pocketbase.yourdomain.com   # or empty for offline-only
   ```
2. Build/run through the helper script, which injects the defines:
   ```powershell
   # Windows
   ./scripts/run.ps1 build web
   ./scripts/run.ps1 build apk --release
   ```
   ```sh
   # macOS / Linux / CI
   ./scripts/run.sh build web
   ./scripts/run.sh build apk --release
   ```

Equivalent manual form (what the script runs):
```sh
flutter build web --dart-define=WISHABLE_PB_URL=https://pocketbase.yourdomain.com
```

> `WISHABLE_PB_URL` empty → the remote layer is inert and the app is purely
> local/offline. Set it to enable the Account & sync screen.

**Never commit `.env`.** Only `.env.example` is tracked. In CI, set the value as
a secret and either write a `.env` from it or pass `--dart-define` directly.

---

## 3. Pre-release checks

```sh
flutter pub get
dart run build_runner build        # regenerate Drift code if schema changed
flutter analyze                    # must be clean
flutter test                       # must be green
```

---

## 4. Release builds per platform

Run these via the helper script so the `--dart-define` config is included, or
append the define manually.

### Web
```sh
flutter build web --release
# Output: build/web/  — deploy as static files (see §5).
```
Web needs `sqlite3.wasm` and `drift_worker.js` in `web/` (already present). If a
host rewrites paths, ensure those two files are served from the app root.

### Windows
```sh
flutter build windows --release
# Output: build/windows/x64/runner/Release/
```
Package the Release folder (e.g. with MSIX via the `msix` package or an
installer). Code-sign the executable for distribution.

### macOS
```sh
flutter build macos --release
# Output: build/macos/Build/Products/Release/Wishable.app
```
Sign and notarize with your Apple Developer ID before distributing.

### Linux
```sh
flutter build linux --release
# Output: build/linux/x64/release/bundle/
```
Package as AppImage / Snap / Flatpak / .deb as preferred.

### Android
```sh
flutter build apk --release          # APK
flutter build appbundle --release    # AAB for Play Store
```
Configure signing in `android/key.properties` + `android/app/build.gradle`
(keystore kept OUT of git). The AAB is what the Play Store wants.

### iOS
```sh
flutter build ipa --release
# Output: build/ios/ipa/
```
Requires a provisioning profile + distribution certificate. Upload via Xcode or
`xcrun altool`/Transporter.

---

## 5. Deploying the web build

`build/web/` is static. Any static host works (Netlify, Vercel, Cloudflare
Pages, GitHub Pages, S3+CloudFront, or the PocketBase server's `pb_public/`).

- Serve over HTTPS.
- Serve `sqlite3.wasm` with `Content-Type: application/wasm`.
- For OPFS-backed storage, the site must be cross-origin isolated for best
  results; Drift falls back to IndexedDB otherwise, which also works.

Serving the web app from PocketBase itself: drop the contents of `build/web/`
into PocketBase's `pb_public/` directory and it will serve the app and the API
from one origin (which also sidesteps CORS for sync).

---

## 6. Deploying PocketBase (for sync)

Only needed if you ship with sync enabled.

1. Put the `pocketbase` binary on a host (small VPS, Fly.io, Railway, etc.).
2. Run it behind HTTPS (a reverse proxy like Caddy/nginx, or the platform's TLS).
   ```sh
   ./pocketbase serve --http=0.0.0.0:8090
   ```
3. Create the admin account and the `users` + `wishes` collections and API rules
   as described in `docs/pocketbase/README.md` / `RUNNING.md §4`.
4. Point the app build at the public URL via `.env` (`WISHABLE_PB_URL`).
5. Back up `pb_data/` regularly — it is the entire backend state.

---

## 7. Versioning & release checklist

- Bump `version:` in `pubspec.yaml` (`<semver>+<build>`, e.g. `0.2.0+2`).
- `flutter analyze` clean, `flutter test` green.
- Build the targets you ship, each with the correct `WISHABLE_PB_URL`.
- Smoke-test: launch, create/edit/delete a Wish, toggle the app lock, and (if
  sync is enabled) sign in and "Sync now" against the production backend.
- Tag the release in git and attach the artifacts.

---

## 8. Troubleshooting

- **Web build fails with `dart:ffi` / `sqlite3` errors**: a native import leaked
  into the web target. Native code must stay behind the conditional-import seams
  in `data/connection/` and `data/account/remote/`. The architecture tests guard
  this — run `flutter test` first.
- **Icons missing / "Failed to load font"**: ensure
  `assets/fonts/MaterialSymbolsOutlined.ttf` is a real font (not a placeholder)
  and that `assets/` + `assets/brand/` + `assets/fonts/` are listed under
  `flutter: assets:` in `pubspec.yaml`.
- **Sync does nothing**: confirm `WISHABLE_PB_URL` was set at build time (not
  just runtime), the server is reachable over HTTPS, and the `wishes` collection
  + API rules match `docs/pocketbase/README.md`.
- **Favicon not updating on web**: browser cache — hard-refresh or bump a query
  string on the icon link.
