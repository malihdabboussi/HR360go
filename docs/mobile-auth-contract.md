# HR360 Go — Mobile Authentication Contract

## Strategy

| Concern | Web (Client) | HR360 Go (Mobile) |
|--------|--------------|-------------------|
| Session | NextAuth JWT cookie | Bearer `accessToken` in `Authorization` header |
| REST transport | Axios `withCredentials: true` | Dio without cookies; `Authorization: Bearer <token>` |
| Login body | AES-256-GCM encrypted password object | Same JSON shape as web |
| Client tag | (none) | `X-Client-App: hr360-go` |
| Token storage | HTTP-only cookie | `flutter_secure_storage` |
| Session TTL | 2 hours (`maxAge` in NextAuth) | Re-login on 401; optional refresh when backend adds it |

## Login

**Endpoint:** `POST /api/v2/self_service/login`

**Headers:** `X-Client-App: hr360-go` (identifies mobile for access gate)

**Request:**
```json
{
  "email": "user@company.com",
  "password": {
    "content": "<base64 ciphertext>",
    "iv": "<base64 12-byte IV>",
    "authTag": "<base64 auth tag>"
  }
}
```

Password plaintext is encrypted client-side with **AES-256-GCM** using `NEXT_PUBLIC_AES_KEY` (hex-encoded 32-byte key). Mobile uses the same algorithm via `lib/core/auth/aes_crypto.dart`.

**Success response:** `employeeData` object (same as web `authorize` callback), including at minimum:

- `accessToken` — JWT or API token for Bearer auth
- `employee_id`, `tenant_id`, `email`, `role`
- `first_name`, `last_name`, `avatar`, `companyName`, `timeZone`
- `menu_permissions` — coarse nav gating (login does **not** ship full legacy `permissions`)
- `role_permission_id`, `permissions_version`
- `attendance`, `notifications` — optional feature flags

**403 `mobile_access_denied`:** role has explicit `mobile-access.read: false`. Missing `mobile-access` key is treated as allowed during migration.

### Permissions after login

Mobile must fetch catalog capabilities like the web Client:

| Endpoint | Purpose |
|----------|---------|
| `GET /api/v2/permissions/me` | Menu-only (`menu_permissions`) |
| `GET /api/v2/permissions/me/detailed` | Sparse `enabled_action_ids` (plain JSON in dev; AES+gzip `encrypted_payload` in production) |

| Catalog ID | Legacy | Controls |
|------------|--------|----------|
| `actions.mobile.access` | `mobile-access.read` | App login / use |
| `actions.mobile.check-in` | `mobile-check-in.read` | Mobile punch |

Soft-default: when the legacy module key is **absent** (pre-migration role), treat as **allowed**. Explicit `read: false` denies.

Web navbar punch remains `actions.time-attendance.remote-checkin` → `check-in.read` (independent of mobile).

## Authenticated requests

All `/api/v2/*` calls MUST include:

```
Authorization: Bearer <accessToken>
Content-Type: application/json
```

Do **not** send NextAuth cookies from mobile; web uses cookies via `withCredentials`, mobile uses Bearer only.

**Re-login after server token changes** so `accessToken` includes `employee_id`, `tenant_id`, and `role`.

## Logout

Client-side only: delete secure storage keys (`access_token`, `session_json`). Optional server revoke when backend exposes `POST /api/v2/self_service/logout`.

## Environment

| Variable | Description |
|----------|-------------|
| `API_BASE_URL` | Same as web `NEXT_PUBLIC_API_URL` |
| `AES_KEY_HEX` | Same as web `NEXT_PUBLIC_AES_KEY` |

Configure via `--dart-define` or `.env` loaded at build time (`lib/config/env.dart`).

## Employee API surface (mobile)

Documented in `lib/core/api/api_endpoints.dart`. Attendance punches use `/api/v2/mobile/attendance/*`.
