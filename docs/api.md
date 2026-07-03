# API Reference

All backend communication goes through **n8n webhook endpoints** backed by **Google Sheets** and **Google Drive**. The app never calls Google APIs directly.

---

## Base URLs

| Constant | Value |
|---|---|
| n8n instance | `https://bernard100.app.n8n.cloud` |
| Workflow canvas | `https://bernard100.app.n8n.cloud/workflow/CMX358vkE6g97w3M` |

All webhook paths below are relative to `https://bernard100.app.n8n.cloud/webhook/`.

---

## Auth Endpoints

### `POST apollo-auth` — Login & Register

**URL:** `https://bernard100.app.n8n.cloud/webhook/apollo-auth`  
**Constant:** `kAuthUrl` in `lib/services/auth_service.dart`

**Login Request:**
```json
{
  "action": "login",
  "email": "user@example.com",
  "username": "user@example.com",
  "password": "secret"
}
```

**Register Request:**
```json
{
  "action": "register",
  "name": "Juan Dela Cruz",
  "fullName": "Juan Dela Cruz",
  "email": "user@example.com",
  "username": "user@example.com",
  "password": "secret",
  "role": "sales",
  "contactNumber": "+63 912 345 6789",
  "address": "123 Sample St., Manila",
  "birthdate": "1995-04-15"
}
```

**Success Response:**
```json
{
  "ok": true,
  "user": {
    "name": "Juan Dela Cruz",
    "email": "user@example.com",
    "role": "sales"
  },
  "token": "<jwt-or-session-token>"
}
```

**Failure Response:**
```json
{
  "ok": false,
  "error": "Invalid credentials"
}
```

**Role values accepted:** `sales`, `hos`, `eng`, `hoe`, `admin` (the app normalizes any spelling variants — see `_normRole()` in `auth_service.dart`).

---

### `GET apollo-users-list` — List All Users

**URL:** `https://bernard100.app.n8n.cloud/webhook/apollo-users-list`  
**Constant:** `kUsersListUrl` in `lib/services/auth_service.dart`

**Response:**
```json
[
  { "name": "Juan Dela Cruz", "email": "juan@example.com", "role": "eng" },
  { "name": "Maria Santos", "email": "maria@example.com", "role": "sales" }
]
```
Used to populate the engineering team picker inside the `eng_assign` pipeline step (Stage 5).

---

## Booking Endpoints

### `POST apollo-booking-create` — Create New Consultation

**URL:** `https://bernard100.app.n8n.cloud/webhook/apollo-booking-create`  
**Constant:** `kBookingCreateUrl` in `lib/services/booking_service.dart`

Fires **once** at finalization. Atomically creates the Google Drive folder and appends the Google Sheet row. If the folder creation fails, **no row is written** — the booking must be retried.

**Request:** Full `ConsultationData` payload (see [Data Models](#data-models) below).

**Success Response:**
```json
{
  "ok": true,
  "folderId": "1ABCxyz...",
  "folderUrl": "https://drive.google.com/drive/folders/1ABCxyz..."
}
```

**Failure Response:**
```json
{
  "ok": false,
  "error": "Folder creation failed"
}
```

---

### `POST apollo-booking-update` — Update Consultation

**URL:** `https://bernard100.app.n8n.cloud/webhook/apollo-booking-update`  
**Constant:** `kBookingUpdateUrl` in `lib/services/booking_service.dart`

Upserts an existing consultation row by `Ref`. Used for all pipeline step updates after initial creation. Never touches the Drive folder.

**Request:** Partial or full consultation payload including the `ref` field.

**Response:** `{ "ok": true }` on success.

---

### `GET apollo-booking-list` — List / Fetch Consultations

**URL:** `https://bernard100.app.n8n.cloud/webhook/apollo-booking-list`  
**Constant:** `kBookingListUrl` (also aliased as `kBookingStatusUrl`) in `lib/services/booking_service.dart`

- **No query params** → returns all bookings.
- **`?ref=APL-0001`** → returns the single matching booking.

**Response (all):**
```json
{
  "ok": true,
  "bookings": [
    {
      "ref": "APL-0001",
      "client": "Juan Dela Cruz",
      "agent": "Maria Santos",
      "classification": "Residential",
      "events": "[{\"stepKey\":\"ocular_booked\",\"date\":\"2025-01-15\",\"actor\":\"maria@example.com\"}]",
      "Deliverables": "{\"quotation\":{\"url\":\"https://...\",\"name\":\"quotation.pdf\"}}"
    }
  ]
}
```

> **Parsing note:** The n8n "Respond With" node can return the payload in several shapes (`{ok,bookings:[...]}`, `[{ok,bookings:[...]}]`, or a bare array). `BookingService.listBookings()` handles all variants.

---

### `POST apollo-deliverable-upload` — Upload File to Drive

**URL:** `https://bernard100.app.n8n.cloud/webhook/apollo-deliverable-upload`  
**Constant:** `kDeliverableUploadUrl` in `lib/services/booking_service.dart`

Uploads a single file (PDF or photo) to the ticket's Google Drive folder. Does **not** update the consultation row — the app folds the returned links into the booking and persists via `BookingService.save()`.

**Request:**
```json
{
  "ref": "APL-0001",
  "type": "quotation",
  "filename": "quotation_APL-0001.pdf",
  "mimeType": "application/pdf",
  "dataBase64": "<base64-encoded-file-contents>",
  "folderId": "1ABCxyz...",
  "client": "Juan Dela Cruz"
}
```

**`type` values:**
| Value | Used In Step | Label |
|---|---|---|
| `quotation` | `ocular_quote` | Final Quotation (PDF) |
| `proof_delivery` | `pod` | Proof of Delivery |
| `install_before` | `install_photos` | Before Photo |
| `install_during` | `install_photos` | During Photo |
| `install_after` | `install_photos` | After Photo |

**Success Response:**
```json
{
  "ok": true,
  "url": "https://drive.google.com/file/d/...",
  "downloadUrl": "https://drive.google.com/uc?id=...",
  "name": "quotation_APL-0001.pdf",
  "folderId": "1ABCxyz..."
}
```

---

### `POST apollo-folder-create` — Create Drive Folder (standalone)

**URL:** `https://bernard100.app.n8n.cloud/webhook/apollo-folder-create`  
**Constant:** `kFolderCreateUrl` in `lib/services/booking_service.dart`

Creates (or finds) the ticket's Google Drive folder named `ClientName-RefNo`. This is a best-effort helper — if it returns `null`, the upload webhook will re-create the folder when the first file is attached.

> **Note:** `apollo-booking-create` also creates the folder as part of its atomic chain. This standalone endpoint is used for edge-case recovery.

**Request:**
```json
{ "ref": "APL-0001", "client": "Juan Dela Cruz" }
```

**Success Response:**
```json
{ "ok": true, "folderId": "1ABCxyz...", "folderUrl": "https://..." }
```

---

### `POST consultation-booked` — Fire Confirmation Email

**URL:** `https://bernard100.app.n8n.cloud/webhook/consultation-booked`  
**Constant:** `kConsultationBookedUrl` in `lib/services/booking_service.dart`

Fire-and-forget. Triggers the n8n workflow that sends a confirmation email to the client. Failure here never blocks the main booking save.

---

## Solar / Pricing Endpoints

### `GET apollo-solar-pricing` — Live Pricing Tiers

**URL:** `https://bernard100.app.n8n.cloud/webhook/apollo-solar-pricing`  
**Constant:** `kPricingUrl` in `lib/utils/solar_calculator.dart`

Returns current solar equipment pricing tiers from the Google Sheet. This overrides the hardcoded fallback tier database in `solar_calculator.dart`.

---

### `GET apollo-du-rates` — Distribution Utility Rate Sheet

**URL:** `https://bernard100.app.n8n.cloud/webhook/apollo-du-rates`  
**Constant:** `kDuRatesUrl` in `lib/utils/solar_calculator.dart`

Returns the manually-maintained electricity rate (₱/kWh) per distribution utility. Called once per session during calculator warm-up. Overrides the fallback `duRates` map in `solar_calculator.dart`.

**Response:**
```json
{
  "ok": true,
  "du_rates": {
    "meralco": 14.48,
    "batelec1": 10.50,
    "batelec2": 9.64,
    "ormeco": 9.68,
    "lima": 9.00,
    "other": 10.00
  },
  "updated_at": "2026-06-01"
}
```

A rate of `0` or blank is ignored — the app keeps the hardcoded fallback for that DU.

---

## Data Models

### ConsultationData Fields

| Field | Type | Description |
|---|---|---|
| `fullName` | `String` | Client full name |
| `contactNumber` | `String` | Client phone number |
| `email` | `String` | Client email |
| `propertyType` | `String` | `Residential` or `Commercial` |
| `address` | `String` | Property address |
| `latitude` | `double` | GPS latitude |
| `longitude` | `double` | GPS longitude |
| `priority` | `String` | `savings`, `zeroBill`, `backup`, `offgrid` |
| `systemType` | `String` | `gridtied` or `hybrid` |
| `bill1–3` | `double` | Last 3 monthly electricity bills (PHP) |
| `distributionUtility` | `String` | `meralco`, `batelec1`, `batelec2`, `ormeco`, `lima`, `other` |
| `roofType` | `String` | `metal`, `concrete`, `tile`, `ground` |
| `roofLength` | `double` | Roof usable length (meters) |
| `roofWidth` | `double` | Roof usable width (meters) |
| `roofDirection` | `String` | `south`, `flat`, `unknown` |
| `obstructions` | `String` | Free-text description of roof obstructions |
| `acuCount` | `int` | (Hybrid) Number of AC units |
| `acuTotalHp` | `double` | (Hybrid) Total AC horsepower |
| `batteryQty` | `int` | (Hybrid) Number of battery units |
| `timeline` | `String` | `asap`, `1-3mo`, `3-6mo`, `justlooking` |
| `leadId` | `String` | Auto-generated reference number (e.g. `APL-0001`) |

---

## Error Handling

All service methods return `false` / `null` on failure and populate a static `lastError` string:

```dart
// Example pattern used across services
if (!await BookingService.save(payload)) {
  showDialog(context, message: BookingService.lastError);
}
```

HTTP timeouts are set to **30 seconds** for auth calls and **60 seconds** for booking/update calls. File uploads allow up to **90 seconds** on mobile networks.
