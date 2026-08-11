# Web

Flutter web application for the Smart Helpdesk admin console and chat widget demo.

## Run

```bash
flutter pub get
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 3000 --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

## Verification

```bash
flutter analyze
flutter test
flutter build web
```
