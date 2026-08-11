# Smart Helpdesk Startup Guide

This guide explains how to run Smart Helpdesk on Windows using the automatic launcher.

## What the launcher starts

Running `start.cmd` starts these parts of the project:

- AI service at `http://127.0.0.1:8001`
- Backend API at `http://127.0.0.1:8000`
- Web dashboard at `http://127.0.0.1:3000`
- Local ChromaDB knowledge base used by the AI service

The Flutter mobile app is optional and is not started automatically because it requires a selected emulator or physical device.

## 1. Install the required system tools

Install these tools before running the project for the first time:

- Python 3.12 or newer
- Flutter SDK
- Git, if you are cloning the repository from GitHub

Verify that the required commands are available:

```powershell
python --version
flutter --version
git --version
```

Each command should print a version number. If Windows cannot find a command, close and reopen PowerShell after installing the tool.

## 2. Download the project

Clone the repository and enter its directory:

```powershell
git clone https://github.com/kaffeinesloth/Little-Birdies.git
cd Little-Birdies
```

Alternatively, download the repository as a ZIP file from GitHub, extract it, and open PowerShell inside the extracted `Little-Birdies` folder.

## 3. Start Smart Helpdesk

From the repository root, run:

```powershell
.\start.cmd -OpenBrowser
```

The first launch automatically:

1. Creates isolated Python virtual environments.
2. Installs the required Python packages.
3. Installs the web application's packages.
4. Starts the AI service.
5. Loads the included sample support-policy document into the knowledge base.
6. Starts the backend API.
7. Starts the web dashboard.
8. Opens the login page in your default browser.

The first launch can take several minutes because dependencies must be downloaded. Keep the terminal open until the launcher reports that Smart Helpdesk is running.

To start without opening the browser automatically, use:

```powershell
.\start.cmd
```

## 4. Log in

Open these pages after startup:

- Login: `http://127.0.0.1:3000/login`
- Chat widget demo: `http://127.0.0.1:3000/widget-demo`
- Unified Inbox: `http://127.0.0.1:3000/inbox`

Administrator account:

```text
Email: owner@example.com
Password: password
```

Agent account:

```text
Email: agent@example.com
Password: password
```

The local demo does not require Supabase, OpenAI, Gemini, Facebook, email, or Firebase credentials. When those credentials are not configured, the application uses its local mock and deterministic AI fallback behavior.

## 5. Stop Smart Helpdesk

From the repository root, run:

```powershell
.\stop.cmd
```

The shutdown script stops only the processes recorded by `start.cmd`. It does not broadly stop unrelated Python or Flutter programs.

## Later launches

Normally, running `start.cmd` again is safe because it only installs dependencies when they are missing.

For a faster startup that requires all dependencies to be present already, use:

```powershell
.\start.cmd -SkipInstall -OpenBrowser
```

If dependency files have changed after pulling new updates from GitHub, run the regular command without `-SkipInstall`.

## Updating the project

Stop Smart Helpdesk before pulling updates:

```powershell
.\stop.cmd
git pull
.\start.cmd -OpenBrowser
```

On macOS/Linux, use:

```sh
./stop.sh
git pull
./start.sh --open-browser
```

## Troubleshooting

### Python or Flutter was not found

Install the missing system tool, close PowerShell, open a new PowerShell window, and verify its version before trying again.

### Port 3000, 8000, or 8001 is already in use

Another application or an earlier development process is using a required port. First try:

```powershell
.\stop.cmd
```

If the launcher says the project was not started by `start.cmd`, inspect the occupied ports:

```powershell
Get-NetTCPConnection -State Listen -LocalPort 3000,8000,8001 -ErrorAction SilentlyContinue |
    Select-Object LocalPort, OwningProcess
```

Do not stop a process until you have confirmed that it is safe to terminate.

### Startup failed

Logs are stored in:

```text
.smart-helpdesk\logs
```

The most useful error logs are:

```text
.smart-helpdesk\logs\ai.err.log
.smart-helpdesk\logs\api.err.log
.smart-helpdesk\logs\web.err.log
```

After correcting the error, run:

```powershell
.\stop.cmd
.\start.cmd -OpenBrowser
```

### PowerShell says script execution is disabled

Run the `.cmd` launchers, not the `.ps1` files:

```powershell
.\start.cmd
.\stop.cmd
```

The command wrappers handle the PowerShell execution policy without changing the computer's permanent policy.

## Optional mobile app

After installing Flutter and starting an Android emulator or connecting a device, run:

```powershell
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

For the standard Android emulator, use `10.0.2.2` to access the Windows host:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

The mobile app currently uses mock authentication and notification fallbacks unless the production Supabase and Firebase integrations are configured.
