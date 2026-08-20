# Unified Smart Helpdesk Demo Setup

This is the presenter handoff guide. The demo now has two user-facing products:

- `store/`: the customer shopping website and chat at `http://localhost:3000`.
- `mobile/`: one adaptive Flutter staff application for web, Android, and iOS. Docker serves its web build at `http://localhost:8080`.

The old React project in `web/` is a deprecated prototype and is not needed for the demo.

## Choose A Demo Mode

### Reliable fallback mode

Use this on any laptop with Docker Desktop. It requires no GPU, API key, Supabase project, or `.env` file.

```powershell
.\scripts\start-demo.ps1
```

The AI replies are deterministic, so this is the safest presentation mode.

### Real local-AI mode

Use this on a Windows laptop with an NVIDIA GPU and at least 8 GB VRAM. A 10–12 GB GPU is recommended for the default Qwen3 8B model.

```powershell
.\scripts\start-demo.ps1 -LocalAI
```

The first startup downloads approximately 6 GB of models and can take several minutes. Docker keeps them in the `ollama_models` volume for later runs.

The local stack uses:

- `qwen3:8b-q4_K_M` for English customer replies.
- `qwen3-embedding:0.6b` for local document retrieval.
- Ollama for GPU inference.
- Local knowledge files and the bundled SportGear document for grounded RAG answers.

If Ollama or its model is not ready, the AI service automatically uses the deterministic fallback instead of breaking the chat.

For a 6–8 GB GPU, create `.env` from `.env.example` and change:

```dotenv
OLLAMA_CHAT_MODEL=qwen3:4b-q4_K_M
```

Do not use the local-AI profile on a CPU-only presentation laptop unless slow responses are acceptable.

## Before Presentation Day

1. Install Docker Desktop and enable its WSL 2 engine.
2. For local AI, install a current NVIDIA driver and enable Docker Desktop GPU support.
3. Clone or copy the repository onto the presentation laptop.
4. Run the preflight check:

```powershell
.\scripts\demo-doctor.ps1
```

For local AI:

```powershell
.\scripts\demo-doctor.ps1 -LocalAI
```

If PowerShell blocks local scripts, run them for the current process with:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

## Verify The Running Demo

Open:

- Customer store: http://localhost:3000
- Unified Flutter staff app: http://localhost:8080
- Backend API docs: http://localhost:8000/api/docs
- AI status: http://localhost:8001/health

The AI health response reports its active provider:

```json
{"status":"ok","provider":"ollama","model":"qwen3:8b-q4_K_M","runtime_ready":true}
```

If it reports `provider: fallback`, wait for `ollama-init` to finish downloading the models:

```powershell
docker compose --profile local-ai logs -f ollama-init
```

Then refresh the staff application.

## Demo Script

1. Open the store at port 3000.
2. Ask: `Do you offer free shipping?`
3. Ask: `How much is the Polo Pro Active, and is size L available?`
4. Send: `My product arrived torn. Please help me resolve this now.`
5. Open the Flutter staff app at port 8080.
6. Select the newest Web Store ticket.
7. Send a staff response.
8. Return to the store and show the response appearing in the chat.
9. Mark the ticket complete.
10. Use the profile menu to demonstrate the Agent and Super Admin views.

The Support Agent role only has the live support workspace. The Administrator role also has Reports & Revenue, staff management, and AI knowledge management.

## Install The Flutter App On Android

Docker hosts the shared backend, but an APK runs directly on the phone. The phone and laptop must be on the same Wi-Fi network.

Find the laptop IPv4 address:

```powershell
ipconfig
```

Build the APK on a computer with Flutter installed:

```powershell
.\scripts\build-demo-apk.ps1 -LaptopIp 192.168.1.50
```

Replace `192.168.1.50` with the presentation laptop's address. Install:

```text
mobile/build/app/outputs/flutter-apk/app-release.apk
```

Allow inbound TCP port 8000 in Windows Firewall if the phone cannot reach the backend. Test from the phone browser first:

```text
http://192.168.1.50:8000/
```

The mobile and browser builds use the same Flutter code and backend data. Their layouts differ adaptively: the browser uses a multi-column workspace while the phone uses list/detail navigation and bottom tabs.

## Knowledge Demo

In Super Admin mode, open `Manage` and select `Upload Document to ChromaDB` (or `Add knowledge` on a phone). Choose a TXT, PDF, or DOCX file from the device, review its name and size, then select `Upload & Index`. Files may be up to 10 MB.

In local mode, the AI service extracts readable text and stores it in the persistent `ai_knowledge_data` Docker volume. The next customer question can retrieve it without Supabase. AI replies remain in English even when an uploaded document uses another language.

Knowledge uploads are intentionally limited to the Super Admin demo role. Store customers cannot modify the AI knowledge base.

## Stop Or Reset

Stop services but preserve models and knowledge:

```powershell
docker compose --profile local-ai down
```

For fallback mode:

```powershell
docker compose down
```

Only use `-v` when you intentionally want to remove downloaded Ollama models and uploaded local knowledge:

```powershell
docker compose --profile local-ai down -v
```

## Presentation Recovery

If local AI is slow or unavailable:

```powershell
docker compose --profile local-ai down
.\scripts\start-demo.ps1
```

The customer-to-staff workflow remains available in fallback mode.
