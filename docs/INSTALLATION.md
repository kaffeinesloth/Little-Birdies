# Smart Helpdesk Installation and Handoff Guide

This document is for a teammate cloning the repository onto a new laptop. The recommended demo is fully containerized and runs without Supabase, cloud AI, or secret keys.

## What Docker Starts

| Service | Purpose | Host URL |
| --- | --- | --- |
| `store-website` | Customer shopping site and chat widget | <http://localhost:3000> |
| `flutter-web` | Responsive staff application | <http://localhost:8080> |
| `backend` | Tickets, messages, users, reports, and demo storage | <http://localhost:8000/api/docs> |
| `ai-service` | Intent detection, RAG, document indexing, and fallback AI | <http://localhost:8001/health> |
| `ollama` | Optional real local LLM | <http://localhost:11434> |

The default stack uses deterministic offline AI and in-memory ticket data. ChromaDB knowledge uploads persist in a Docker volume. Restarting containers is safe; `docker compose down --volumes` deliberately resets persistent demo data.

## System Requirements

### Standard demo

- 64-bit Windows 10/11, current macOS, or Linux
- Git 2.40 or newer
- Docker Desktop 4.x, or Docker Engine 25+ and Docker Compose v2
- 8 GB system RAM minimum; 12 GB recommended
- 8 GB free disk space
- Ports `3000`, `8000`, `8001`, and `8080` available

### Optional local AI

- 16 GB system RAM recommended
- Approximately 10 GB additional disk space for Ollama models
- Port `11434` available
- Optional: NVIDIA GPU with current driver and Docker GPU support for faster responses

The local-AI profile can run on CPU-only Windows Docker Desktop, but first response latency is much slower than GPU. The standard fallback demo is still the safest presentation mode on low-spec laptops.

## Fresh Installation

### Windows

1. Install Git and Docker Desktop.
2. In Docker Desktop, use the WSL 2 engine and wait until the engine says it is running.
3. Open PowerShell:

```powershell
git clone https://github.com/kaffeinesloth/Little-Birdies.git
cd Little-Birdies
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\demo-doctor.ps1
.\scripts\start-demo.ps1
```

### macOS or Linux

Install Git and Docker with the Compose v2 plugin, then run:

```bash
git clone https://github.com/kaffeinesloth/Little-Birdies.git
cd Little-Birdies
sh scripts/demo-doctor.sh
sh scripts/start-demo.sh
```

The launcher builds images, starts containers in the background, waits for health checks, and prints all demo URLs.

## Optional Environment Files

No environment files are required for the offline demo. To override defaults or connect external services, copy only the examples you need:

Windows PowerShell:

```powershell
Copy-Item .env.example .env
Copy-Item backend/.env.example backend/.env
Copy-Item ai_service/.env.example ai_service/.env
Copy-Item store/.env.example store/.env
```

macOS/Linux:

```bash
cp .env.example .env
cp backend/.env.example backend/.env
cp ai_service/.env.example ai_service/.env
cp store/.env.example store/.env
```

Never commit copied `.env` files or real credentials. Root `.env` values are Docker/browser build settings. Backend and AI secrets belong only in their service-specific files.

## Real Local AI with Ollama

Start the optional profile:

Windows:

```powershell
.\scripts\start-demo.ps1 -LocalAI
```

macOS/Linux:

```bash
sh scripts/start-demo.sh --local-ai
```

The first run downloads `qwen3:8b-q4_K_M` and `qwen3-embedding:0.6b`, so it can take several minutes. The launcher waits until `/health` reports the Ollama model is ready. Check progress with:

```bash
docker compose --profile local-ai logs --follow ollama-init
```

Verify the provider:

```bash
curl http://localhost:8001/health
```

When the model is ready, the response reports `"provider":"ollama"` and `"runtime_ready":true`. Until then, the application remains usable with fallback responses.

For a smaller GPU or CPU-only laptop, copy `.env.example` to `.env` and set a smaller Ollama chat model that exists in your Ollama registry.

## Android Demo App

Docker serves the backend on the laptop. The phone and laptop must use the same Wi-Fi network.

1. Install Flutter stable and Android SDK tooling on the build computer.
2. Find the laptop IPv4 address with `ipconfig` on Windows or `ip addr`/`ifconfig` on macOS/Linux.
3. On Windows, build with:

```powershell
.\scripts\build-demo-apk.ps1 -LaptopIp 192.168.1.50
```

4. Install `mobile/build/app/outputs/flutter-apk/app-release.apk` on the Android phone.
5. If it cannot connect, allow inbound TCP ports `8000` and `8001` through the laptop firewall and verify `http://LAPTOP_IP:8000/` from the phone browser.

The APK embeds the laptop address at build time. Rebuild it if the laptop IP changes.

## Manual Development Without Docker

Docker is strongly recommended for the handoff. For developers who want hot reload:

### Backend

```bash
python -m venv .venv
# Activate .venv for your shell
python -m pip install -r backend/requirements.txt
cd backend
uvicorn main:app --reload --port 8000
```

### AI service

Use a separate virtual environment because it has a larger dependency set:

```bash
python -m venv .venv-ai
# Activate .venv-ai for your shell
python -m pip install -r ai_service/requirements.txt
cd ai_service
uvicorn main:app --reload --port 8001
```

### Customer store

```bash
cd store
npm ci
npm run dev
```

### Flutter staff application

```bash
cd mobile
flutter pub get
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=AI_BASE_URL=http://localhost:8001
```

Use Python 3.12, Node.js 20, and the Flutter version compatible with `mobile/pubspec.lock`.

## Useful Docker Commands

```bash
docker compose ps
docker compose logs --follow
docker compose logs --follow backend
docker compose up --build --detach --wait
docker compose down
docker compose --profile local-ai down --volumes
```

## Troubleshooting

### Docker is not running

Start Docker Desktop, wait for the engine, then run the doctor script again.

### A port is already in use

Stop the process or container using `3000`, `8000`, `8001`, `8080`, or optional `11434`. Then restart the demo.

### A stale web page appears

```bash
docker compose build --no-cache store-website flutter-web
docker compose up --detach --wait
```

Then hard-refresh the browser.

### Local AI is unavailable

```bash
docker compose --profile local-ai down
docker compose up --detach --wait
```

### Inspect startup failures

```bash
docker compose ps
docker compose logs backend ai-service flutter-web store-website
```

## Demo Scope and Security

This repository is currently a demonstration build. Demo role switching is UI-level, demo endpoints do not require production authentication, and the fallback ticket store is not a production database. Do not expose this stack directly to the public internet or use real customer data without implementing server-side authentication, authorization, persistent database policies, secret management, and production deployment controls.
