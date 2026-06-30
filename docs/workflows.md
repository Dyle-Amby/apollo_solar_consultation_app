# Workflows & Roles

## User Roles

The app supports five roles. Each role has access to a specific subset of pipeline steps.

| Role Key | Label | Can Act On |
|---|---|---|
| `sales` | Sales Agent | Sales-owned steps |
| `hos` | Head of Sales | Sales + HOS-owned steps |
| `eng` | Engineer | Engineering-owned steps |
| `hoe` | Head of Engineering | Engineering + HOE-owned steps |
| `admin` | Admin | All steps |

---

## Consultation Intake Flow (8-Step Wizard)

A Sales Agent initiates a new consultation by filling out an 8-step wizard. All data is collected into a single `ConsultationData` object and submitted at the `finalize_screen`.

| Step | Screen | Data Collected |
|---|---|---|
| 1 | `step1_client_info.dart` | Full name, contact, email, property type, address, GPS coordinates |
| 2 | `step2_priority.dart` | Client priority: Savings / Zero Bill / Backup / Off-Grid |
| 3 | `step3_system_type.dart` | System type: Grid-Tied or Hybrid |
| 4 | `step4_electricity.dart` | Last 3 monthly electricity bills, distribution utility (Meralco, Batelec, etc.) |
| 5 | `step5_roof_info.dart` | Roof type, dimensions (L × W), orientation, obstructions |
| 6 | `step6_battery.dart` | (Hybrid only) Number and HP of AC units, battery quantity |
| 7 | `step7_timeline.dart` | Installation timeline: ASAP / 1–3 months / 3–6 months / Just Looking |
| 8 | `step8_result_screen.dart` | Computed solar recommendation (from `SolarCalculator`) |

After Step 8, the agent proceeds to `finalize_screen.dart` to review and submit. On submit, `BookingService.createBooking()` fires — this atomically creates the Google Drive folder and appends the row to the Google Sheet.

---

## Ticket Pipeline (21 Steps)

Once a consultation is submitted, it becomes a **ticket** tracked through 21 pipeline steps across 7 stages. The pipeline is defined in `ticket_pipeline.dart` as `kTicketSteps`.

```
Stage 1 · Ocular Visit          (Sales)
  └─ ocular_booked              Book the ocular visit date

Stage 2 · Ocular (Engineering)  (Engineering)
  ├─ ocular_ack                 Acknowledge the ocular visit date
  ├─ ocular_underway            Mark ocular as underway
  ├─ ocular_ongoing             Mark ocular as ongoing
  ├─ ocular_finished            Mark ocular as finished
  ├─ ocular_quote               Submit Final Quotation PDF (deliverable required)
  └─ hos_quote_ok               Head of Sales approves the quotation

Stage 3 · Quotation to Client   (Sales)
  ├─ quote_sent                 Send the final quotation to the client
  └─ second_opinion             Record second-opinion outcome (optional)

Stage 4 · Client Approval       (Sales)
  ├─ client_ok                  Record client decision (For Closing / Workable / Lost)
  ├─ delivery_date              Book delivery date
  └─ install_date               Book installation date

Stage 5 · Engineering Approval  (Engineering / HOS)
  ├─ eng_assign                 Assign engineering team
  ├─ eng_dates                  Engineering confirms / adjusts dates
  └─ hos_final                  Head of Sales gives final approval

Stage 6 · Delivery              (Engineering)
  ├─ materials_underway         Mark materials as underway
  ├─ delivery_way               Mark delivery as on the way
  └─ pod                        Upload Proof of Delivery photo (deliverable required)

Stage 7 · Installation          (Engineering)
  ├─ install_underway           Mark installation as underway
  ├─ install_photos             Upload Before / During / After photos (deliverable required)
  └─ completed                  Mark installation as complete
```

### Client Decision Outcomes (`client_ok` step)

| Outcome | Meaning | Ticket Effect |
|---|---|---|
| `closing` | For Closing — client approved | Ticket proceeds to Stages 5–7 |
| `workable` | Still negotiating | Ticket parks on `client_ok`, re-decidable later |
| `lost` | Did Not Push Through | Ticket closes; no further actions required |

### Deliverable Steps

Three steps require a file to be uploaded before they can be marked complete:

| Step Key | Required File(s) |
|---|---|
| `ocular_quote` | Final Quotation PDF |
| `pod` | Proof of Delivery photo |
| `install_photos` | Before, During, After installation photos |

Files are uploaded to the ticket's Google Drive folder (named `ClientName-RefNo`) via `BookingService.uploadDeliverable()`.

---

## Dashboard & Notifications

The **Dashboard** (`dashboard.dart`) displays:
- **Awaiting You** — tickets where the current pipeline step is owned by the signed-in user's role.
- **In Progress** — tickets actively moving through the pipeline.
- **Completed** — tickets that have reached the `completed` step.

The **Notification bell** (`notification_screen.dart`) shows the same "Awaiting You" queue but tracks which items the user has already seen using `shared_preferences`, enabling a "new unread" badge count.
