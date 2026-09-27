# HR360 Go (Flutter)

Employee mobile app extracted from the HRMS web **Client**. Focus: reliable attendance (GPS, offline sync) and employee self-service modules.

## Prerequisites

- Flutter SDK 3.16+ (`flutter doctor`)
- Same backend as web (`NEXT_PUBLIC_API_URL`)
- Same AES key as web (`NEXT_PUBLIC_AES_KEY`)

## First-time setup

From this directory:

```bash
# Generate android/ ios/ etc. if missing
flutter create . --project-name hr360_go

flutter pub get
```

## Run

Copy `.env.example` to `.env` and set `API_BASE_URL` and `AES_KEY_HEX` (same as web `NEXT_PUBLIC_API_URL` / `NEXT_PUBLIC_AES_KEY`).

```bash
cp .env.example .env
flutter run -d chrome
# App URL: http://localhost:8080 (fixed in web_dev_config.yaml)
```

Or:

```bash
./scripts/run_web.sh
```

Optional overrides still work via `--dart-define=API_BASE_URL=...` / `AES_KEY_HEX=...`.

### Login extras

- **Show password** — eye icon on the password field  
- **Remember me** — stores email/password in secure storage (and session token still keeps you signed in)  
- **Check for updates** — compares app version to `LATEST_APP_VERSION` in `.env` and opens `IOS_STORE_URL` / `ANDROID_STORE_URL`

### Physical iPhone

`localhost` in `.env` points at the **phone**, not your Mac. Use your Mac’s LAN IP:

```bash
ipconfig getifaddr en0
# then set API_BASE_URL=http://192.168.x.x:5001 in .env
flutter run -d <iphone-id>
```

Phone and Mac must be on the same Wi‑Fi. Restart `flutter run` after editing `.env` (it is bundled as an asset).

## Design system

Brand colors, typography (Inter), spacing, and component rules match the HRMS web **Client**. See **[docs/design-tokens.md](docs/design-tokens.md)**. Flutter themes live in `lib/core/theme/` (`AppColors`, `AppTheme.light` / `AppTheme.dark`).

## Project layout

| Path | Purpose |
|------|---------|
| `docs/design-tokens.md` | Brand tokens (colors, spacing, Figma handoff) |
| `docs/mobile-api-spec.md` | API surface aligned with web Client |
| `docs/ATTENDANCE_PARITY_TRACKER.md` | **Web ↔ mobile attendance parity matrix** |
| `docs/mobile-auth-contract.md` | Bearer auth + login encryption contract |
| `docs/offline-attendance-protocol.md` | Pending punch + Plan B local session |
| `lib/features/attendance/` | Check-in flow (Plan B, queue, poll, pending punch) |
| `lib/features/shifts/` | Coming soon (no web API yet) |
| `lib/features/employee/` | Profile, leaves, tasks, training, payroll |
| `assets/l10n/` | Copied from `Client/transaltion/*.json` |

Before changing attendance code, read **[docs/ATTENDANCE_PARITY_TRACKER.md](docs/ATTENDANCE_PARITY_TRACKER.md)**.

## Features implemented

- **Auth**: AES-256-GCM password encryption + `POST /api/v2/self_service/login` + secure token storage
- **Attendance**: Full web parity — `checkinTime`, primary queue response, Plan B fallback, pending punch, status poll, optimistic local session
- **Offline**: Pending punch recovery on connectivity restore (mirrors web `AttendanceCheckInProvider`)
- **Shifts**: Tab placeholder until backend exposes schedule APIs used by web
- **Workspace**: Permission-gated employee modules mirroring web `my-workspace` tabs

## API alignment

See `docs/mobile-api-spec.md`. Mobile uses **Bearer token only** (not NextAuth cookies).

## Tests

```bash
flutter test
```
