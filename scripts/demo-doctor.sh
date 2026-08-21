#!/usr/bin/env sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$PROJECT_ROOT"

LOCAL_AI=0
for arg in "$@"; do
  case "$arg" in
    --local-ai) LOCAL_AI=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

echo "Smart Helpdesk demo check"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker was not found. Install and start Docker Desktop or Docker Engine." >&2
  exit 1
fi

docker compose version
docker info --format 'Docker engine: {{.ServerVersion}}'
docker compose config --services

if [ "$LOCAL_AI" -eq 1 ]; then
  echo "Required host ports: 3000, 8000, 8001, 8080, 11434"
  if ! command -v nvidia-smi >/dev/null 2>&1; then
    echo "No NVIDIA runtime was detected. Ollama will run on CPU, which is slower but works for the demo."
  fi
else
  echo "Required host ports: 3000, 8000, 8001, 8080"
fi
echo "Preflight check complete."
