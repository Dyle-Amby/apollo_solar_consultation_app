# Apollo Consultation — Backend Architecture & Handover

One-page map of how the Flutter app talks to n8n + Google Sheets/Drive. Everything
lives in **one n8n workflow canvas**; each capability is a separate webhook entry
point. The app (`booking_service.dart`) decides which webhook to call and when.

## Webhook endpoints (all on `https://bernard100.app.n8n.cloud/webhook/...`)

| Path | Fires when | What its chain does | Called by (Dart) |
|---|---|---|---|
| `apollo-booking-create` | Finalising a NEW consultation | Make Drive folder → append row (folder baked in) → status history → respond `{ok,folderId,folderUrl}`. **Hard-fail:** folder error → `{ok:false}`, no row. | `BookingService.createBooking()` ← `finalize_screen._save()` |
| `apollo-booking-update` | Every status change / edit / deliverable save AFTER booking | Build row → **append-or-update by REF_CODE** → status history → respond `{ok:true}`. No folder logic. | `BookingService.save()` |
| `apollo-booking-list` | Opening History, or one ticket | No `?ref` → all rows; `?ref=` → one. Maps sheet columns back to app keys. | `listBookings()`, `getByRef()` |
| `apollo-deliverable-upload` | Attaching a PDF / photo to a step | Decode base64 → ensure folder (create-if-missing) → upload to Drive → respond links. Never writes the row (app does). | `uploadDeliverable()` |
| `consultation-booked` | After a successful booking with a date | Confirmation email (Gmail). **Leave untouched.** Fire-and-forget. | `fireConsultationBooked()` |
| `apollo-auth` | Login / Register | Airtable user lookup/create + password check. | `auth_service.dart` |
| `apollo-users-list` | Opening the Engineering-team picker (step 13) | Lists all Airtable users as `{name,email,role}` (role normalized). | `AuthService.listUsers()` |
| `apollo-du-rates` | Calculator warm-up (each session) | Reads the **manual** DU price sheet → `{du_rates:{meralco,batelec1,batelec2,ormeco,...}}`. Rate of 0/blank is ignored (keeps fallback). | `fetchDuRates()` in `solar_calculator.dart` |

## The one rule that keeps data clean

**The app is the single writer of a ticket row.** The upload webhook only puts files
in Drive and returns links; the app folds those links into its `deliverables` map and
persists them via `apollo-booking-update`. So a status change never wipes a deliverable,
and a file upload never races the row. `events`, `consultation`, `deliverables`, and the
folder columns are all re-sent on every update for this reason.

## Create vs Update — why they're separate

The folder must exist **before** the row is written. `create` does folder→row in one
ordered call; `update` never touches the folder (it already exists). If they were one
webhook, every status change would try to re-create the folder. The meaningful
difference between the two chains is literally just the **Create Booking Folder** node.

## Google Sheets — IMPORTANT mapping gotcha

`Save Consultations` uses **`defineBelow`** (explicit column mapping), NOT "Map
Automatically." The sheet headers are OLD-STYLE; Build Row outputs CANONICAL names;
the node maps canonical → sheet column. **To add a new column you must add it to the
node's column mapping** — refreshing columns alone does nothing.

| Sheet header (actual) | ← mapped from Build Row key |
|---|---|
| REF_CODE | Ref |
| ClientName | Client Name |
| Contact Number | Contact No |
| PropertyType | Property Type |
| OcularDate / InstallationDate / DeliveryDate | Ocular Date / Installation Date / Delivery Date |
| CurrStatus / CurrOwner | Current Status / Current Owner |
| Drive Folder ID / Drive Folder URL / Deliverables | (same names) |
| (others: Email, Location, Agent, System Type, Priority, Avg Monthly Bill, Monthly kWh, Distribution Utility, Timeline, Roof Type/Length/Width, Obstructions, Additional Notes, Events, Consultation) | (same names) |

- Tab `Sheet10` = **Consultations** (one flat row per ticket, matched on REF_CODE).
- Tab `Sheet11` = **Status_History** (append-only audit log).

## Google Drive — folders & deliverables

- One folder per ticket, named **`ClientName-RefNo`**, under the Shared Drive
  `1xh98oNiXsmT9fSE9EEPKCKtZ3Tyz5nX-`.
- The row's `Drive Folder ID` / `Drive Folder URL` columns store the link.
- `Deliverables` is a JSON object keyed by type:
  `quotation`, `proof_delivery`, `install_before`, `install_during`, `install_after`,
  each `{url, downloadUrl, name, by, at}`. The ticket UI reads this to show View/Download.
- Which step needs which file is defined in `ticket_pipeline.dart` → `kStepDeliverables`.

## Roles (Airtable label → app key)

Sales→`sales`, Head of Sales→`hos`, Engineering→`eng`, Head of Engineering→`hoe`,
Admin→`admin`. Step ownership + who-can-act is in `ticket_pipeline.dart` (`canActOn`).

## All endpoint URLs are centralised

In `services/booking_service.dart` as `k...Url` constants. Change a path in ONE place.

## Notifications (Tier 1 — in-app, no push)

`NotificationService` computes each user's queue (tickets whose current step is
owned by their role, not closed) straight from `listBookings()` — no backend, no
new tables. The dashboard shows a **bell + red badge** of NEW items (unseen since
the inbox was last opened; seen-state stored per-user in `shared_preferences`),
refreshed every 60s and on app-resume. Tapping the bell opens
`NotificationsScreen` (the queue), which marks everything seen.

**This is the seam for later tiers** — keep the inbox UI, swap the source:
- **Tier 2** (accurate unread + history): the update workflow writes a row to a
  `Notifications` sheet/table targeted at the next role/person; the app reads that
  instead of recomputing from bookings. Capture engineer **emails** (not just
  names) at step 13 so notifications can target specific people.
- **Tier 3** (real push while app closed): add `firebase_messaging` — one Flutter
  API covers **both Android (FCM) and iOS (APNs)**. On login, register the device
  token against the user; when n8n writes a Tier-2 notification, it also calls FCM
  to push. Needs a Firebase project + (for iOS) an APNs key. Note this adds an
  external dependency with its own availability, like the Google services above.



This app leans heavily on **Google Sheets** (system of record) and **Google Drive**
(deliverables), via n8n. That means Google's own uptime, quotas, and rate limits are
part of *our* failure surface. Expect, occasionally:

- **`503 Service unavailable` / "try again later"** from the Sheets or Drive node — a
  transient Google-side outage or throttle, NOT a bug in our workflow. Symptom in the
  app: an **`Update failed: TimeoutException`** or **empty-response** dialog, while the
  n8n execution may keep running in the background (and may need a manual stop).
- **Rate limits** if many saves fire in a short burst (Sheets API has per-minute quotas).
- **Slow responses** that exceed the app's network timeout even when the write eventually
  succeeds — so the row updates but the app still shows an error.

**Mitigations already in place:**
1. **Retry On Fail** is enabled on all four Sheets nodes (`Save New Consultation`,
   `Save Consultation Update`, `Save Status History` ×2): Max Tries 3, Wait 2000 ms.
   Most 503s clear on the first retry. If you add/replace a Sheets or Drive node,
   **turn this on** (node → Settings → Retry On Fail).
2. **Respond-before-history ordering:** each chain answers the app the moment the row is
   saved, then writes Status History after. So a slow history append can't time out the app.
3. **App timeouts** in `booking_service.dart` give headroom for retries (create/update 60s,
   upload 90s). Don't drop these below the worst-case retry time.
4. **Tolerant parsing:** the app never crashes on an empty/non-JSON response; it shows a
   readable message and the user can retry.

**If a timeout still happens:** it's almost always transient — the user retries and it
goes through. Check the n8n **Executions** log; if the failing node says *"From Google
Sheets / Drive: service unavailable"*, that's Google, wait and retry. Only dig deeper if
it fails on **every** attempt (then suspect credential/quota, not an outage).

**Possible future hardening** (not built yet, note for whoever scales this): a lightweight
client-side retry/queue so saves that fail on a Google blip are retried automatically;
and/or moving the system-of-record off Sheets to a real database (Airtable/Postgres) if
write volume grows past Sheets' comfortable range.

## When something breaks — first checks

- **New columns blank in the sheet** → the column isn't in `Save Consultations`'
  defineBelow mapping. Add it there.
- **Folder not created / "resource not found"** → open the Create Folder node: parent
  must be a real folder ID in the Shared Drive (not the literal `ROOT_FOLDER_ID`), and
  the Drive credential must be valid.
- **App shows "response was empty"** → a node errored before the Respond node. Open the
  n8n **Executions** log for that webhook and read the failing node.
- **Webhook 404 from the app** → the workflow isn't **Active** (production URLs only
  work when active).