# Quickstart: Clone and Run

This is the shortest setup path for the Smart Helpdesk demo. It requires no API keys, database account, Flutter installation, Node.js installation, or Python installation.

## Requirements

- Git
- Docker Desktop 4.x (Windows/macOS) or Docker Engine with Compose v2 (Linux)
- At least 8 GB RAM and 8 GB free disk space
- Free ports: `3000`, `8000`, `8001`, and `8080`

On Windows, start Docker Desktop before continuing.

## 1. Clone

```bash
git clone https://github.com/kaffeinesloth/Little-Birdies.git
cd Little-Birdies
```

## 2. Start

Windows PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\start-demo.ps1
```

macOS/Linux:

```bash
sh scripts/start-demo.sh
```

Or use Docker Compose directly on any platform:

```bash
docker compose up --build --detach --wait
```

The first build can take several minutes. No `.env` file is needed for the standard offline demo.

## 3. Open

- Customer shopping demo: <http://localhost:3000>
- Unified staff application: <http://localhost:8080>
- Backend API documentation: <http://localhost:8000/api/docs>
- AI service status: <http://localhost:8001/health>

## 4. Demonstrate

1. Open the shopping demo and send `Do you offer free shipping?`
2. Send `My Polo arrived torn. Please help me replace it.`
3. Open the staff application and select the newest Web conversation.
4. Reply as an agent and mark the conversation Resolved.
5. The resolved conversation can now be deleted with **Delete Chat**.
6. Switch to Administrator to show Reports, staff management, and document upload. Support Agent only has the support workspace.

## Stop

```bash
docker compose down
```

Uploaded knowledge and downloaded models are preserved in Docker volumes. To intentionally erase them too:

```bash
docker compose down --volumes
```

For local Ollama AI, Android installation, manual development, and troubleshooting, read [INSTALLATION.md](INSTALLATION.md).
