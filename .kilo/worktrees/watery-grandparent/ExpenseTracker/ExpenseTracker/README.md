# MoneyTracker — Cross-Platform Expense Tracker

> **Stack:** Flutter + Dart · Node.js + Express · PostgreSQL · Claude Vision API

---

## Tech Stack

### Frontend — Flutter (Dart)
| Package | Purpose |
|---|---|
| `flutter_riverpod` | State management (providers, async notifiers) |
| `go_router` | Declarative navigation, deep links |
| `dio` | HTTP client with interceptors & auth injection |
| `mobile_scanner` | Real-time QR code scanning (iOS, Android) |
| `image_picker` | Camera + gallery access for receipt scanning |
| `fl_chart` | Bar charts and analytics visualizations |
| `flutter_animate` | Micro-animations and screen transitions |
| `flutter_secure_storage` | Encrypted JWT storage |
| `google_fonts` | DM Sans typography |
| `freezed` + `json_serializable` | Immutable models with JSON serialization |

**Runs on:** iOS · Android · Web · macOS · Windows · Linux

---

### Backend — Node.js + Express
| Package | Purpose |
|---|---|
| `express` | HTTP server, routing |
| `pg` + `pg-pool` | PostgreSQL client with connection pooling |
| `bcryptjs` | Password hashing (12 rounds) |
| `jsonwebtoken` | JWT auth (30-day tokens) |
| `multer` + `sharp` | Receipt image upload + resize/optimize |
| `axios` | Claude Vision API calls |
| `helmet` | Security headers |
| `express-rate-limit` | DDoS/brute-force protection |
| `express-validator` | Input validation |
| `winston` | Structured logging |
| `dayjs` | Date arithmetic for analytics |

---

### Database — PostgreSQL 16
- `users` — accounts, currency preference
- `transactions` — all income/expense entries
- `budgets` — per-category monthly/weekly limits
- `receipt_scans` — audit log of all AI scans

---

### AI — Anthropic Claude Vision
- Receipt images are resized via `sharp`, base64-encoded, and sent to `claude-sonnet-4-20250514`
- Returns structured JSON: merchant, line items, tax, total
- QR data is parsed locally with regex fallbacks for non-JSON formats (DuitNow, GrabPay, etc.)

---

## Project Structure

```
moneytracker/
├── frontend/                        # Flutter app
│   ├── lib/
│   │   ├── main.dart                # App entry, router, shell
│   │   ├── theme/
│   │   │   └── app_theme.dart       # Colors, typography, category metadata
│   │   ├── models/
│   │   │   └── transaction.dart     # Freezed models (Transaction, Budget, etc.)
│   │   ├── services/
│   │   │   └── api_service.dart     # All HTTP calls via Dio
│   │   ├── providers/
│   │   │   └── providers.dart       # Riverpod state providers
│   │   └── screens/
│   │       ├── home/                # Balance hero, quick actions, recent tx
│   │       ├── transactions/        # Full history list
│   │       ├── analytics/           # Charts + category breakdown
│   │       ├── budget/              # Budget cards + add sheet
│   │       ├── add_transaction/     # Full add form
│   │       ├── scanner/
│   │       │   ├── qr_scanner_screen.dart
│   │       │   └── receipt_scanner_screen.dart
│   │       └── widgets/
│   │           └── transaction_tile.dart
│   └── pubspec.yaml
│
├── backend/                         # Node.js API
│   ├── src/
│   │   ├── index.js                 # Express app, middleware, routes
│   │   ├── db/
│   │   │   ├── pool.js              # PostgreSQL connection pool
│   │   │   └── migrate.js           # Schema migrations
│   │   ├── middleware/
│   │   │   ├── auth.js              # JWT verification
│   │   │   ├── logger.js            # Winston logger
│   │   │   └── error-handler.js     # Global error handler
│   │   └── routes/
│   │       ├── auth.js              # POST /auth/register, /auth/login
│   │       ├── transactions.js      # CRUD /transactions
│   │       ├── analytics.js         # GET /analytics?period=week|month|year
│   │       ├── budgets.js           # CRUD /budgets
│   │       └── scan.js              # POST /scan/receipt, /scan/qr
│   ├── .env.example
│   ├── Dockerfile
│   └── package.json
│
└── docker-compose.yml               # PostgreSQL + API + pgAdmin
```

---

## Setup

### 1. Prerequisites
- Flutter SDK 3.2+: https://flutter.dev/docs/get-started/install
- Node.js 18+
- PostgreSQL 14+ (or Docker)
- Anthropic API key: https://console.anthropic.com

### 2. Backend

```bash
cd backend
cp .env.example .env
# Edit .env — add DB credentials and ANTHROPIC_API_KEY

npm install
node src/db/migrate.js       # Create all tables
npm run dev                  # Start with hot reload
```

Or with Docker:

```bash
docker compose up -d         # Starts postgres + api
docker compose exec api node src/db/migrate.js
```

### 3. Flutter App

```bash
cd frontend
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

**Run on specific platform:**
```bash
flutter run -d chrome        # Web
flutter run -d ios           # iOS Simulator
flutter run -d android       # Android Emulator
flutter run -d macos         # macOS Desktop
flutter run -d windows       # Windows Desktop
```

**Set API URL for each platform:**
```bash
# Web / Desktop
flutter run --dart-define=API_BASE_URL=http://localhost:3000/api

# iOS device (replace with your machine's local IP)
flutter run --dart-define=API_BASE_URL=http://192.168.1.x:3000/api
```

---

## API Reference

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| POST | `/api/auth/register` | ✗ | Create account |
| POST | `/api/auth/login` | ✗ | Get JWT token |
| GET  | `/api/auth/me` | ✓ | Current user |
| GET  | `/api/transactions` | ✓ | List with filters |
| POST | `/api/transactions` | ✓ | Create transaction |
| PUT  | `/api/transactions/:id` | ✓ | Update transaction |
| DELETE | `/api/transactions/:id` | ✓ | Delete transaction |
| GET  | `/api/analytics?period=month` | ✓ | Spending summary |
| GET  | `/api/budgets` | ✓ | List budgets + spent |
| POST | `/api/budgets` | ✓ | Create/upsert budget |
| PUT  | `/api/budgets/:id` | ✓ | Update limit |
| DELETE | `/api/budgets/:id` | ✓ | Delete budget |
| POST | `/api/scan/receipt` | ✓ | Claude Vision receipt scan |
| POST | `/api/scan/qr` | ✓ | Parse QR code data |

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Flutter App                        │
│  iOS · Android · Web · macOS · Windows · Linux      │
│                                                     │
│  Riverpod Providers ──► Dio HTTP Client             │
│  mobile_scanner ──► QR decode                       │
│  image_picker   ──► Receipt image                   │
└──────────────────────┬──────────────────────────────┘
                       │ HTTPS / JWT
┌──────────────────────▼──────────────────────────────┐
│           Node.js + Express API                     │
│                                                     │
│  /auth         bcryptjs + JWT                       │
│  /transactions PostgreSQL CRUD                      │
│  /analytics    Aggregated SQL queries               │
│  /budgets      Upsert with spend join               │
│  /scan/receipt sharp resize ──► Claude Vision API   │
│  /scan/qr      JSON + regex parsing                 │
└──────────┬───────────────────┬──────────────────────┘
           │                   │
┌──────────▼──────┐   ┌────────▼────────────────────┐
│  PostgreSQL 16  │   │  Anthropic Claude API        │
│                 │   │  claude-sonnet-4-20250514     │
│  users          │   │  Vision: receipt → JSON      │
│  transactions   │   └─────────────────────────────┘
│  budgets        │
│  receipt_scans  │
└─────────────────┘
```

---

## Platform-specific notes

### iOS
- Add to `ios/Runner/Info.plist`:
  ```xml
  <key>NSCameraUsageDescription</key>
  <string>Used to scan QR codes and receipts</string>
  <key>NSPhotoLibraryUsageDescription</key>
  <string>Used to upload receipts from your photo library</string>
  ```

### Android
- `mobile_scanner` requires `minSdkVersion 21` in `android/app/build.gradle`

### Web
- Camera QR scanning works on Chrome/Safari via `mobile_scanner`'s web implementation
- `flutter_secure_storage` falls back to `localStorage` on web

### macOS / Windows / Linux (Desktop)
- QR camera scanning uses the desktop webcam via `mobile_scanner`
- Receipt upload uses `image_picker`'s file dialog
