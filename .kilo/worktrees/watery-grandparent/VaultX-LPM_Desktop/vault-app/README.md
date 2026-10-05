# 🔐 Vault — Local Password Manager

A clean, local-first password manager built with Electron, React, and Node.js. No cloud, no accounts, no telemetry. Your data stays on your machine, encrypted with AES-256-GCM.

## Security model

- **Master password** → Argon2id (64MB memory, 3 iterations) → 256-bit key
- **Each credential** → AES-256-GCM encrypted blob stored in SQLite
- **Session key** lives only in memory — never written to disk
- **Auto-lock** after 5 minutes of inactivity
- **Clipboard** auto-clears after 30 seconds
- Renderer process never touches plaintext or the key — all crypto in main process via IPC

## Tech stack

| Layer | Tech |
|-------|------|
| UI | React 18 + Vite |
| Desktop shell | Electron 29 |
| Crypto | Node `crypto` (AES-256-GCM) + `argon2` (Argon2id) |
| Storage | `better-sqlite3` — single `.db` file in app data dir |
| Fonts | DM Sans + DM Mono |

## Project structure

```
vault-app/
├── electron/
│   ├── main.js          # App entry, window creation
│   ├── preload.js       # contextBridge — safe IPC bridge
│   └── ipc/
│       ├── vault.js     # unlock, list, save, delete + session management
│       ├── clipboard.js # copy + 30s auto-clear
│       └── generator.js # password generation
├── src/                 # React (Vite)
│   ├── App.jsx          # Root router (loading → setup/locked → unlocked)
│   ├── screens/
│   │   ├── UnlockScreen.jsx   # Master password entry + first-time setup
│   │   └── VaultScreen.jsx    # Main vault with sidebar + detail panel
│   └── components/
│       ├── CredentialCard.jsx # Sidebar list item with favicon
│       ├── CredentialForm.jsx # Add/edit form with password strength meter
│       └── Generator.jsx      # Password generator with options
├── db/
│   └── schema.js        # SQLite init + helpers
└── crypto/
    └── vault-crypto.js  # Argon2 + AES-256-GCM + password generator
```

## Getting started

### Prerequisites

- Node.js 18+
- npm 9+

### Install

```bash
cd vault-app
npm install
```

> **Note**: `argon2` and `better-sqlite3` are native modules. On first install, they will compile from source. You need `python` and a C++ compiler:
> - **macOS**: `xcode-select --install`
> - **Windows**: `npm install --global windows-build-tools`
> - **Linux**: `sudo apt install build-essential python3`

### Run in development

```bash
npm run dev
```

This starts Vite dev server on port 5173, then launches Electron pointing at it. Hot reload works for the React layer.

### Build for production

```bash
npm run build
```

Output goes to `dist-electron/`. The app bundles everything into a native installer.

## Data location

The vault database is stored at:

| Platform | Path |
|----------|------|
| macOS | `~/Library/Application Support/vault-app/vault.db` |
| Windows | `%APPDATA%\vault-app\vault.db` |
| Linux | `~/.config/vault-app/vault.db` |

## Features (v1)

- [x] First-time vault setup with master password
- [x] Unlock / lock with Argon2id key derivation
- [x] Auto-lock after 5 minutes of inactivity
- [x] Store login credentials (title, URL, username, password, notes)
- [x] Search / filter credentials in real time
- [x] Password strength meter on credential form
- [x] One-click copy for username and password (clipboard clears in 30s)
- [x] Password generator with length + charset options
- [x] Inline generator inside the credential form
- [x] Favicon loading for visual recognition
- [x] Animated toast notifications
- [x] Delete with confirmation

## Planned (v2)

- [ ] Categories / folders
- [ ] Import from CSV / 1Password / Bitwarden
- [ ] Export (encrypted JSON)
- [ ] Auto-lock on screen lock / sleep
- [ ] Browser extension companion
- [ ] TOTP / 2FA code support

## Security notes

- The master password is **never stored** — only a verification blob encrypted with the derived key.
- If you forget your master password, your vault **cannot be recovered**. This is by design.
- The session key is held as a Node.js `Buffer` in the main process and zeroed with `buf.fill(0)` on lock.
- All IPC calls go through `contextBridge` — the renderer has no direct Node.js access.
