# HR360 Go — Offline attendance (pending punch)

Aligned with web `Client/lib/attendance-pending-punch.ts`.

## Model

Single durable record in Hive (`pending_punch_store.dart`), key `hr360_pending_attendance_punch`.

| Field | Notes |
|-------|--------|
| `checkinTime` | ISO UTC — captured once at confirm |
| `timeZone` | IANA |
| `expectedAction` | `check_in` / `check_out` |
| `status` | `pending` \| `queued` \| `failed` |
| `baselineStatus` | Snapshot before punch for confirmation |
| `attempts` | Max 12 silent retries |

## Flow

1. Save pending punch before network call.
2. **Primary success (legacy)** → clear pending.
3. **Primary queued** → mark `queued`, poll `GetCheckinStatus` until confirmed.
4. **Plan B success** → clear pending, save `local_attendance_session` for optimistic UI.
5. **Failed retryable** → mark `failed`, retry on connectivity restore.

## Plan B local session

Separate Hive store (`local_attendance_session_store.dart`) until server status reconciles.

## No geofence gate

Web does not block punch when GPS unavailable; mobile matches (optional geo).
