# Apollo Solar Consultation App

The Apollo Solar Consultation App is an internal tool developed for Apollo Solar Ventures. It is designed to streamline the client consultation and project pipeline process, from initial sales contact to engineering design and final quotation.

## Core Features

- **Role-Based Access Control**: Tailored dashboards and actions for Sales Agents, Head of Sales (HOS), Engineers, Head of Engineering (HOE), and Admin.
- **Consultation Ticket Pipeline**: A structured 21-step workflow that tracks client transactions across 7 stages — from initial ocular visit booking through to completed installation.
- **Dashboard & Analytics**: Quick overview of tickets awaiting your action, in progress, and completed.
- **Costing & Specifications**: Aids sales agents in providing approximate costing and system specifications based on client details during the consultation.
- **Geolocation & Mapping**: Integrated maps for site location tagging using `flutter_map` and `geolocator`.
- **Document Management**: Supports file and image attachments uploaded directly to Google Drive via `file_picker` and `image_picker`.
- **PDF Generation**: Automated PDF report generation and printing using the `pdf` and `printing` packages.

## Tech Stack

- **Framework:** Flutter / Dart (`^3.12.0`)
- **Backend:** n8n automation webhooks → Google Sheets + Google Drive
- **Key Dependencies:**
  - `flutter_map`, `latlong2`, & `geolocator` for mapping and location
  - `pdf` & `printing` for document generation
  - `http` for API requests
  - `image_picker`, `flutter_image_compress`, & `file_picker` for media/file handling
  - `url_launcher` for external links
  - `shared_preferences` for local notification state

## Getting Started

1. Ensure you have the [Flutter SDK](https://docs.flutter.dev/get-started/install) installed (version `^3.12.0` or higher).
2. Clone the repository and navigate to the project directory.
3. Run `flutter pub get` to install all dependencies.
4. Run `flutter run` to launch the application on your connected device or emulator.

## Documentation

| Document | Description |
|---|---|
| [Architecture](docs/architecture.md) | Folder structure, state management, and key design decisions |
| [Workflows & Roles](docs/workflows.md) | User roles, the 8-step consultation wizard, and the 21-step ticket pipeline |
| [Setup Guide](docs/setup.md) | Prerequisites, environment configuration, and build instructions |
| [API Reference](docs/api.md) | n8n webhook endpoints, request/response shapes, and data models |
