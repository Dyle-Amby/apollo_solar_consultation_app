# Setup & Development Guide

## Prerequisites

| Tool | Required Version | Notes |
|---|---|---|
| Flutter SDK | `^3.12.0` | [Install guide](https://docs.flutter.dev/get-started/install) |
| Dart SDK | Included with Flutter | Minimum SDK constraint: `^3.12.0` |
| Android Studio / Xcode | Latest stable | For Android / iOS emulator & build tools |
| VS Code (recommended) | Latest stable | With the Flutter & Dart extensions |

---

## Getting Started

```bash
# 1. Clone the repository
git clone <repository-url>
cd apollo_solar_consultation_app

# 2. Install dependencies
flutter pub get

# 3. Verify your Flutter environment
flutter doctor

# 4. Run on a connected device or emulator
flutter run
```

---

## Running on Specific Platforms

```bash
# Android
flutter run -d android

# iOS (macOS only)
flutter run -d ios

# Web
flutter run -d chrome

# Windows Desktop
flutter run -d windows
```

---

## Key Dependencies

| Package | Version | Purpose |
|---|---|---|
| `http` | `^1.6.0` | API calls to n8n webhooks |
| `flutter_map` | `^7.0.2` | Interactive map for location tagging |
| `latlong2` | `^0.9.1` | Lat/lng coordinate types for `flutter_map` |
| `geolocator` | `^13.0.1` | "Use My Location" GPS button |
| `pdf` | `^3.11.1` | PDF report generation |
| `printing` | `^5.13.3` | Print / share PDF reports |
| `file_picker` | `^8.1.2` | File attachment for deliverables |
| `image_picker` | `^1.2.2` | Camera / gallery photo picker |
| `flutter_image_compress` | `^2.4.0` | Compress images before upload |
| `shared_preferences` | `^2.3.2` | Persist notification "seen" state |
| `url_launcher` | `^6.3.1` | Open Google Drive links externally |

---

## Environment & Backend Configuration

There are **no `.env` files** — all backend URLs are hardcoded constants in the service layer. If the n8n instance or webhook paths change, update the relevant constants:

| Constant | File | Purpose |
|---|---|---|
| `kAuthUrl` | `lib/services/auth_service.dart` | Login & Registration endpoint |
| `kUsersListUrl` | `lib/services/auth_service.dart` | List all registered users |
| `kBookingCreateUrl` | `lib/services/booking_service.dart` | Create new consultation (+ Drive folder) |
| `kBookingUpdateUrl` | `lib/services/booking_service.dart` | Update an existing consultation row |
| `kBookingListUrl` | `lib/services/booking_service.dart` | Fetch all / one consultation(s) |
| `kConsultationBookedUrl` | `lib/services/booking_service.dart` | Fire confirmation email workflow |
| `kFolderCreateUrl` | `lib/services/booking_service.dart` | Create Google Drive folder |
| `kDeliverableUploadUrl` | `lib/services/booking_service.dart` | Upload file to Drive folder |
| `kPricingUrl` | `lib/utils/solar_calculator.dart` | Fetch live solar pricing tiers |

> **Note:** All endpoints point to `https://bernard100.app.n8n.cloud/webhook/...`. Coordinate with the backend owner before changing these.

---

## Building for Production

```bash
# Android APK
flutter build apk --release

# Android App Bundle (recommended for Play Store)
flutter build appbundle --release

# iOS (macOS only, requires Xcode signing)
flutter build ios --release

# Web
flutter build web --release

# Windows
flutter build windows --release
```

---

## Linting & Code Analysis

The project uses `flutter_lints ^6.0.0`. Run analysis at any time:

```bash
flutter analyze
```

Lint rules are configured in [`analysis_options.yaml`](../analysis_options.yaml) at the project root.
