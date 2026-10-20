# UNIHUB (uni_events_app)

Multi-tenant university events platform built with Flutter.

- **Students:** discover campus and public events, register, hold QR tickets, leave reviews.
- **Planners:** publish events, scan tickets at the door, view attendance and feedback.
- Per-university branding (TUM, LMU, UHH), light/dark themes, English and German.

> **Status:** front-end prototype. All data is in-memory mock data; there is no backend or
> authentication yet. See `UNIHUB_Platform_Report.pdf` for the feature inventory, known
> issues and roadmap.

## Getting started

```bash
flutter pub get
flutter run            # pick a device: Chrome, Android, iOS...
flutter analyze
flutter test
```

The QR scanner needs a camera (Android/iOS). On other platforms it shows a fallback and the
"Mock Scan Ticket" button can be used instead.

## Project layout

| Path | Purpose |
|------|---------|
| `lib/main.dart` | App entry, theme and locale wiring |
| `lib/core/auth/user_role.dart` | `AppState` (single ChangeNotifier) |
| `lib/core/models/` | `Event`, `Review` |
| `lib/core/services/` | In-memory `EventRepository` |
| `lib/features/student/` | Home, details, tickets, review, profile |
| `lib/features/planner/` | Dashboard, create event, QR scanner |
| `lib/features/shell/` | Role-based navigation shell |
| `lib/l10n/` | ARB files (en, de) |

## Contributing

CI (`.github/workflows/ci.yml`) runs `flutter analyze` and `flutter test` on every push and PR.
