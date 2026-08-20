# Quickstart: Clone And Run

This is the shortest path for teammates who pull the repo from GitHub and want to run the final non-Zalo demo.

## Requirements

Install:

- Git
- Docker Desktop or Docker Engine with Docker Compose v2

Optional for local development without Docker:

- Python 3.12
- Node.js 20
- Flutter stable

## 1. Clone

```bash
git clone <YOUR_GITHUB_REPO_URL>
cd Little-Birdies
```

## 2. Start The Demo

No `.env` files are required for the fallback class demo.

```bash
docker compose up --build
```

Wait until all four services are healthy/running.

## 3. Open URLs

- Store customer chat: http://localhost:3000
- Flutter staff/admin UI: http://localhost:8080
- Backend API docs: http://localhost:8000/api/docs
- AI health: http://localhost:8001/health

## 4. Demo Messages

Type these in the store chat:

```text
Shop có freeship không?
Áo Polo Pro Active giá bao nhiêu và có size L không?
Sản phẩm bị rách rồi, shop xử lý ngay giúp mình!
```

Then open Flutter, select the newest `Web Store` ticket, send a staff reply, and click `Hoàn Tất & Đóng`.

## Optional Env Files

Only copy these when using real Supabase/Gemini/Realtime credentials:

```bash
cp .env.example .env
cp backend/.env.example backend/.env
cp ai_service/.env.example ai_service/.env
cp store/.env.example store/.env
```

Keep values blank for fallback demo mode. Never commit `.env` files.

The root `.env` is only for Docker Compose build-time browser values. Backend and AI secrets belong in their own service env files.

## Optional Seed

Only seed when real Supabase credentials are configured:

```bash
cd backend
python seed.py

cd ../ai_service
python seed_knowledge.py --mode auto
```

## Stop

```bash
docker compose down
```

To also remove local AI vector data:

```bash
docker compose down -v
```

## If Docker Fails

Check Docker is running:

```bash
docker compose version
docker compose config --services
```

If `docker.sock` is missing, start Docker Desktop and run `docker compose up --build` again.
