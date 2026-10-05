# VaultX — Desktop Password Manager

Zero-knowledge local password manager built with Electron.

## Quick Start

```bash
# 1. Install dependencies
npm install

# 2. Run in development
npm start
```

## Build Installers

```bash
# Windows (.exe installer + portable)
npm run build:win

# macOS (.dmg)
npm run build:mac

# Linux (.AppImage + .deb)
npm run build:linux

# All platforms
npm run build:all
```

Outputs go to the `dist/` folder.

## Tech Stack

- **Electron 29** — cross-platform desktop shell
- **Web Crypto API** — AES-256-GCM encryption, PBKDF2 key derivation (310,000 iterations)
- **Vanilla JS / HTML / CSS** — zero frontend framework
- **electron-builder** — packaging for Win/Mac/Linux

## Security

- Master password is never stored — only used at runtime to derive the AES key
- Vault file stored at: `%APPDATA%/vaultx/vault.vaultx` (Windows), `~/Library/Application Support/vaultx/` (macOS), `~/.config/vaultx/` (Linux)
- All clipboard operations go through Electron's native clipboard API
- Context isolation + preload script — no Node.js access from renderer

## Features

- Logins, Cards, Secure Notes, Identities
- Password Generator (length 8–64, configurable charset)
- Vault Health (weak, reused, old passwords)
- Import: .vaultx, CSV (Bitwarden/LastPass/Chrome/1Password), JSON
- Export: encrypted .vaultx, CSV, JSON (native save dialog)
- Native file dialogs, native clipboard
- Keyboard shortcuts: Ctrl+N (new), Ctrl+L (lock), Ctrl+F (search)
