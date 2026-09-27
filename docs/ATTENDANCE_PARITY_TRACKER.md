# Attendance parity tracker (Web Client ↔ HR360 Go)

Last reviewed: 2026-06-30  
Web baseline: `Client/lib/attendance-*.ts`, `Client/components/attendance/AttendanceCheckInProvider.tsx`

## How to use

1. When web attendance changes, append a row to **Web change log**.
2. Update **Feature matrix** status: ✅ Parity | ⚠️ Partial | ❌ Missing | 🔄 In progress
3. Run gap review before each HR360 Go release.

## Feature matrix

| Capability | Web reference | Flutter reference | Status | Notes |
|------------|---------------|-------------------|--------|-------|
| checkinTime on primary | `attendance-checkin-service.ts` | `attendance_checkin_service.dart` | ✅ | ISO UTC at confirm |
| Queued response handling | `attendance-checkin-response.ts` | `attendance_checkin_response.dart` | ✅ | `{ queued: true }` |
| Plan B fallback | `attendance-checkin-service.ts` | `attendance_checkin_service.dart` | ✅ | POST emergency-checkin |
| Compact JWT for Plan B | `attendance-auth-token.ts` | `attendance_auth_token.dart` | ✅ | 3-segment JWT |
| Pending punch storage | `attendance-pending-punch.ts` | `pending_punch_store.dart` | ✅ | Hive, single punch |
| Status poll after queue | `attendance-checkin-poll.ts` | `attendance_checkin_poll.dart` | ✅ | 2.5s + 5×2s |
| Plan B local session | `attendance-local-session.ts` | `local_attendance_session_store.dart` | ✅ | Optimistic UI |
| 6s check-out cooldown | `AttendanceCheckInProvider.tsx` | `attendance_controller.dart` | ✅ | |
| Optional GPS | `get-browser-position-optional.ts` | `location_service.dart` | ✅ | Best-effort |
| GetCheckinStatus timer | `AttendanceCheckInProvider.tsx` | `attendance_controller.dart` | ✅ | parseOpenCheckinLocalTime |
| Interaction lock while pending | `AttendanceCheckInProvider.tsx` | `attendance_controller.dart` | ✅ | |
| Online retry listener | `AttendanceCheckInProvider.tsx` | `main.dart` bootstrap | ✅ | connectivity_plus |
| Mobile punch permission | `actions.mobile.check-in` | `check_in_permission.dart` + mobile routes | ✅ | Separate from web remote-checkin |
| Mobile app access | `actions.mobile.access` | login `X-Client-App` + session | ✅ | 403 when explicitly denied |

## API contract checklist

| Item | Web | Mobile | Match? |
|------|-----|--------|--------|
| GET Checkin params | `timeZone`, `checkinTime`, geo* | Same | ✅ |
| Primary timeout | 9s | 9s | ✅ |
| Plan B POST path | `{PLAN_B_URL}/attendance/emergency-checkin` | Same | ✅ |
| Plan B source | `frontend_plan_b` | `frontend_plan_b` | ✅ |
| Plan B auth | Bearer compact JWT | Same | ✅ |
| GET GetCheckinStatus | `timeZone` | Same | ✅ |

## Web change log (append-only)

| Date | Web file(s) | Change summary | Mobile action needed |
|------|-------------|----------------|----------------------|
| 2026-07-15 | Roles catalog Mobile apps | Separate `actions.mobile.access` / `actions.mobile.check-in` + `/api/v2/mobile/attendance/*` | ✅ Wired in HR360 Go |
| 2026-07-15 | catalog / `use-catalog-permissions.ts` | Remote check-in gated by catalog action + soft-default (login has no legacy `permissions`) | Hydrate `/permissions/me/detailed`; mobile now uses mobile.* ids |
| 2026-06-30 | `attendance-checkin-service.ts`, pending punch libs | Plan B + queue-first Checkin + pending punch | Initial parity port to HR360 Go |

## Known intentional differences

| Item | Reason |
|------|--------|
| Storage | Hive (`pending_punch_store`) vs `localStorage` — same JSON shape |
| Plan B HTTP client | Separate Dio to Lambda URL (not `API_BASE_URL`) |
