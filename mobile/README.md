# Smart Helpdesk Mobile

Flutter application for Smart Helpdesk staff.

Current responsibilities:

- Login with a Supabase Auth-compatible local placeholder.
- Online and Offline availability toggle.
- API client for `backend/api` with local mock fallback.
- Inbox and ticket detail views for support workflows.
- Notifications screen for urgent ticket alerts.
- Role-aware access for `super_admin` and `agent`.
- Simple dashboard statistics for `super_admin`.
- Settings/Profile screen.

Run locally:

```sh
flutter analyze
flutter test
flutter run
```
