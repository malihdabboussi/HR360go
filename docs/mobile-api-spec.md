# HR360 Go — Mobile API Specification

> Source: `Client/lib/attendance-*.ts`, `Client/utils/queries.ts`, `Client/utils/payrollQueries.ts`

See also: [ATTENDANCE_PARITY_TRACKER.md](ATTENDANCE_PARITY_TRACKER.md)

## Environment

| Variable | Web equivalent |
|----------|----------------|
| `API_BASE_URL` | `NEXT_PUBLIC_API_URL` |
| `AES_KEY_HEX` | `NEXT_PUBLIC_AES_KEY` |
| `ATTENDANCE_PLAN_B_ENABLED` | `NEXT_PUBLIC_ATTENDANCE_PLAN_B_ENABLED` |
| `ATTENDANCE_PLAN_B_URL` | `NEXT_PUBLIC_ATTENDANCE_PLAN_B_URL` |

## Authentication

- `POST /api/v2/self_service/login` — AES password body
- Header **`X-Client-App: hr360-go`** required so the server can enforce `mobile-access`
- `Authorization: Bearer {accessToken}` on API calls

## Mobile attendance (preferred)

Mobile punches use a dedicated mount (same controller as web, different permission gates):

| Method | Path | Permission |
|--------|------|------------|
| GET | `/api/v2/mobile/attendance/Checkin` | `mobile-check-in.read` |
| GET | `/api/v2/mobile/attendance/GetCheckinStatus` | `mobile-check-in.read` |
| GET | `/api/v2/mobile/attendance/getMyAttendance` | `mobile-access.read` |

Web continues to use `/api/v2/attendance/*` + catalog `actions.time-attendance.remote-checkin`.

### GET `/api/v2/mobile/attendance/Checkin`

| Query | Required |
|-------|----------|
| `timeZone` | Yes |
| `checkinTime` | Yes (ISO-8601 UTC) |
| `latitude`, `longitude`, `accuracy`, `locationCapturedAt` | No |

Timeout: **9 seconds**. Queue source tag: `mobile_app`.

**Responses:**

- Legacy: `{ Checkin_Details: { ... } }`
- Queued: `{ queued: true, success?, status?, checkinTime?, message? }`

### POST `{PLAN_B_URL}/attendance/emergency-checkin`

When primary fails (5xx, network, timeout) and Plan B enabled.

- Header: `Authorization: Bearer {compact JWT}`
- Body: `{ checkinTime, timeZone, source: "frontend_plan_b", optional geo }`
- Expect HTTP 200; `success: false` is failure

### GET `/api/v2/mobile/attendance/GetCheckinStatus?timeZone=...`

Fields: `checkin_status` (bool), `checkin_time`, `checkout_time`

### GET `/api/v2/mobile/attendance/getMyAttendance?start_date=&end_date=`

Dates: `yyyy-mm-dd`

## Poll after primary queue

Initial delay 2.5s, then 5 attempts every 2s until status confirms punch.
