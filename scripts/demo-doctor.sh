#!/usr/bin/env sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$PROJECT_ROOT"

echo "Smart Helpdesk demo check"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker was not found. Install and start Docker Desktop or Docker Engine." >&2
  exit 1
fi

docker compose version
docker info --format 'Docker engine: {{.ServerVersion}}'
docker compose config --services

echo "Required host ports: 3000, 8000, 8001, 8080"
echo "Preflight check complete."
