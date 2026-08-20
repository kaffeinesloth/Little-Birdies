# Smart Helpdesk Unified Staff App

This Flutter project is the single staff application for web, Android, and iOS. It provides the shared ticket inbox, customer conversation, reports, demo roles, staff management, and local knowledge management with adaptive layouts.

Docker builds its web target for `http://localhost:8080`. Native builds must receive the backend address at build time:

```powershell
flutter build apk --release `
  --dart-define=API_BASE_URL=http://192.168.1.50:8000 `
  --dart-define=AI_BASE_URL=http://192.168.1.50:8001
```

See [../docs/UNIFIED_DEMO_SETUP.md](../docs/UNIFIED_DEMO_SETUP.md) for the complete presenter setup.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
