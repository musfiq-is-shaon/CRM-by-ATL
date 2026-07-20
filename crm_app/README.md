# CRM Mobile App

Flutter-based CRM application for managing sales, contacts, tasks, attendance, leaves, expenses, profile, and notifications.

## Overview

This project is a mobile CRM client connected to the production backend:

- Base URL: `https://crm.apptriangle.com`
- API docs/source collection: `../CRM_API_Postman_Collection (2).json`

The app uses Riverpod for state management and Dio for API communication.

## Core Features

- Authentication (login, logout, change password, forgot password)
- Dashboard with quick actions and notifications access
- Sales and deals management
- Contacts and companies management
- Tasks list, details, and updates
- Expenses (single/round trip with a single amount input)
- Attendance (today status + records)
- Leave management (apply, list, details, edit, admin flows)
- Profile and company profile pages/editing
- Role-aware menu and screens (admin/user behavior)
- Theme toggle (light/dark)

## Tech Stack

- Flutter / Dart (`sdk: ^3.11.0`)
- `flutter_riverpod` for state management
- `dio` for networking
- `flutter_secure_storage` for secure local storage
- `go_router` (available in dependencies)
- `intl`, `url_launcher`, `file_picker`, `shimmer`, `flutter_slidable`, `confetti`

## Project Structure

```text
crm_app/
├── lib/
│   ├── core/                  # constants, network, theme, shared helpers
│   ├── data/
│   │   ├── models/            # API/domain models
│   │   └── repositories/      # data access layer
│   ├── presentation/
│   │   ├── providers/         # Riverpod notifiers/providers
│   │   ├── pages/             # UI pages/screens
│   │   └── widgets/           # reusable UI widgets
│   ├── app.dart
│   └── main.dart
├── assets/
├── android/
├── ios/
└── pubspec.yaml
```

## Getting Started

### Prerequisites

- Flutter SDK installed
- Android Studio/Xcode configured
- A connected emulator/simulator or device

### Install

```bash
cd crm_app
flutter pub get
```

### Run

```bash
flutter run
```

If changes are not reflected during active development, do a clean run:

```bash
flutter clean
flutter pub get
flutter run
```

## Build

### Android APK (release)

```bash
flutter build apk --release
```

### Android App Bundle

```bash
flutter build appbundle --release
```

### iOS (release)

```bash
flutter build ios --release
```

## API Notes

- API endpoint constants are centralized in `lib/core/constants/app_constants.dart`.
- Postman collection is the source of truth for request/response shapes:
  - `../CRM_API_Postman_Collection (2).json`

## Development Guidelines

- Keep UI state in Riverpod providers/notifiers.
- Keep API parsing/shape adaptation inside repository/model layers.
- Use `AppThemeColors` and shared widgets (`CRMCard`, etc.) for visual consistency.
- Run checks before commit:

```bash
flutter analyze
flutter test
```

## Troubleshooting

- **Stale UI after edits**: do full restart (`flutter clean && flutter pub get && flutter run`).
- **Dependency issues**: run `flutter pub get` again and restart IDE.
- **Platform build issues (iOS)**: run `pod install` inside `ios/` if required by CocoaPods changes.

