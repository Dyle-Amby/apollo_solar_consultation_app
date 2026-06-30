# API Reference

All backend communication goes through **n8n webhook endpoints** backed by **Google Sheets** and **Google Drive**. The app never calls Google APIs directly.

---

## Auth Endpoints

### `POST apollo-auth` — Login & Register

**URL:** `https://bernard100.app.n8n.cloud/webhook/apollo-auth`

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

**Role values accepted:** `sales`, `hos`, `eng`, `hoe`, `admin` (the app normalizes any spelling variants).

---

### `GET apollo-users-list` — List All Users

**URL:** `https://bernard100.app.n8n.cloud/webhook/apollo-users-list`

**Response:**
```json
[
  { "name": "Juan Dela Cruz", "email": "juan@example.com", "role": "eng" },
  { "name": "Maria Santos", "email": "maria@example.com", "role": "sales" }
]
```
Used to populate the engineering team picker inside the `eng_assign` pipeline step.

---

## Booking Endpoints

### `POST apollo-booking-create` — Create New Consultation

**URL:** `https://bernard100.app.n8n.cloud/webhook/apollo-booking-create`

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

---

### `POST apollo-booking-update` — Update Consultation

**URL:** `https://bernard100.app.n8n.cloud/webhook/apollo-booking-update`

Upserts an existing consultation row by `Ref`. Used for all pipeline step updates after initial creation.

**Request:** Partial or full consultation payload including the `ref` field.

**Response:** `{ "ok": true }` on success.

---

### `GET apollo-booking-list` — List / Fetch Consultations

**URL:** `https://bernard100.app.n8n.cloud/webhook/apollo-booking-list`

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

---

### `POST apollo-deliverable-upload` — Upload File to Drive

**URL:** `https://bernard100.app.n8n.cloud/webhook/apollo-deliverable-upload`

Uploads a single file (PDF or photo) to the ticket's Google Drive folder.

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

### `POST consultation-booked` — Fire Confirmation Email

**URL:** `https://bernard100.app.n8n.cloud/webhook/consultation-booked`

Fire-and-forget. Triggers the n8n workflow that sends a confirmation email to the client. Failure here never blocks the main booking save.

---

## Solar Pricing Endpoint

### `GET apollo-solar-pricing` — Live Pricing Tiers

**URL:** `https://bernard100.app.n8n.cloud/webhook/apollo-solar-pricing`

Returns current solar equipment pricing tiers from the Google Sheet. This overrides the hardcoded fallback in `solar_calculator.dart`.

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
| `distributionUtility` | `String` | `meralco`, `batelec1`, `batelec2`, `lima`, `other` |
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

HTTP timeouts are set to **30 seconds** for auth calls and **60 seconds** for booking/upload calls. File uploads allow up to **90 seconds** on mobile networks.
