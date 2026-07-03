# Architecture

## Overview

Apollo Solar Consultation App is a Flutter application that acts as an internal CRM/pipeline tool for Apollo Solar Ventures. It connects to an **n8n** automation backend and a **Google Sheets** data store. There is no dedicated database server — all records live in a single Google Sheet tab, accessed via n8n webhook endpoints.

```
Flutter App  ←→  n8n Webhooks  ←→  Google Sheets / Google Drive
```

---

## Folder Structure

```
lib/
├── main.dart                        # App entry point, session-aware route gate
├── models/
│   └── consultation_data.dart       # Shared data object for the 8-step consultation flow
├── screens/
│   ├── auth/
│   │   ├── login.dart               # Login screen
│   │   ├── registration.dart        # Registration screen
│   │   └── forgot_pass.dart         # Password reset screen
│   └── home/
│       ├── dashboard.dart           # Role-aware dashboard with ticket queue
│       ├── notification_screen.dart # In-app notification inbox
│       └── consultation/
│           ├── consultation_flow.dart      # Orchestrates the 8-step wizard
│           ├── consultation_steps/         # One file per wizard step (Step 1–8)
│           │   ├── step1_client_info.dart
│           │   ├── step2_priority.dart
│           │   ├── step3_system_type.dart
│           │   ├── step4_electricity.dart
│           │   ├── step5_roof_info.dart
│           │   ├── step6_battery.dart
│           │   ├── step7_timeline.dart
│           │   └── step8_result_screen.dart
│           ├── finalize_screen.dart        # Review & submit screen
│           ├── consultation_ticket.dart    # The 21-step ticket tracker UI
│           ├── consultation_details.dart   # Read-only detail view for a ticket
│           └── consultation_history.dart   # List of all past consultations
├── services/
│   ├── session.dart                 # In-memory auth session (name, email, role, token)
│   ├── auth_service.dart            # Login/register → n8n apollo-auth webhook
│   ├── booking_service.dart         # CRUD for consultation rows → n8n booking webhooks
│   ├── ticket_pipeline.dart         # Pipeline definition: 21 steps, role ownership, helpers
│   └── notification_service.dart    # Computes per-role action queues from bookings
├── utils/
│   ├── solar_calculator.dart        # Solar sizing engine + live DU rate fetch
│   └── consultation_pdf.dart        # PDF report generator using the pdf package
└── widgets/
    ├── choice_card.dart             # Reusable selection card widget
    ├── location_picker_field.dart   # Map-based location picker (flutter_map + geolocator)
    └── step_scaffold.dart           # Common scaffold/layout wrapper for wizard steps
```

---

## State Management

The app uses **plain Dart classes with `setState`** — no external state management library (no Provider, Bloc, Riverpod). State flows through:

| Layer | Mechanism |
|---|---|
| Auth session | `Session` singleton (static fields: `name`, `email`, `role`, `token`) |
| Consultation wizard data | `ConsultationData` object, passed down through the step navigator |
| Ticket pipeline state | Derived on-the-fly from the `events` JSON column on each booking row |
| Notifications | `NotificationService.queueFrom(bookings)` computed on each dashboard refresh |

---

## Key Design Decisions

### No Persistent Local Session
`Session` is in-memory only. A cold restart always returns the user to `LoginScreen`. A future enhancement is to persist the session with `shared_preferences`.

### Event-Sourced Ticket State
Each consultation ticket stores an `events` JSON array (e.g., `[{ "stepKey": "ocular_booked", "date": "...", "actor": "..." }]`). The current pipeline step is derived by finding the first `kTicketStep` whose key is **not yet** in the events set. This means no status field ever needs to be manually updated — the pipeline state is always computed from the immutable event log.

### Single Flat Row per Consultation
Each consultation maps to exactly one row in Google Sheets, keyed by a `Ref` number (`APL-XXXX`). The `events` column and `Deliverables` column store JSON. This avoids relational joins but means all updates must be full-row upserts via `BookingService.save()`.

### App Is the Single Row Writer
The deliverable-upload webhook only stores files in Drive and returns links. The app is responsible for folding those links into the `deliverables` map and persisting the row via `apollo-booking-update`. This prevents race conditions between status changes and file uploads.

### Live Pricing & DU Rates via n8n
`solar_calculator.dart` ships hardcoded fallback data for both equipment tiers and distribution utility (DU) electricity rates. At startup:
- `fetchLivePricing()` calls `apollo-solar-pricing` to pull current equipment prices from the Google Sheet.
- `fetchDuRates()` calls `apollo-du-rates` to pull current ₱/kWh rates per DU.

This keeps the app in sync with the website calculator without a code release.

### Role-Based Action Gating
`ticket_pipeline.dart` defines `kRolePermissions` — which step-owner types each account role may act on. `canActOn(userRole, stepOwner)` is the single gatekeeper used by both the ticket tracker UI and the dashboard's "Awaiting You" list to ensure they always agree.
