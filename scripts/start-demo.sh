#!/usr/bin/env sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$PROJECT_ROOT"

LOCAL_AI=0
NO_BUILD=0
for arg in "$@"; do
  case "$arg" in
    --local-ai) LOCAL_AI=1 ;;
    --no-build) NO_BUILD=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

if [ "$LOCAL_AI" -eq 1 ]; then
  sh "$PROJECT_ROOT/scripts/demo-doctor.sh" --local-ai
else
  sh "$PROJECT_ROOT/scripts/demo-doctor.sh"
fi

if [ "$LOCAL_AI" -eq 1 ]; then
  set -- compose --profile local-ai up --detach --wait
else
  set -- compose up --detach --wait
fi

if [ "$NO_BUILD" -eq 0 ]; then
  set -- "$@" --build
fi

docker "$@"

if [ "$LOCAL_AI" -eq 1 ]; then
  echo "Waiting for Ollama model readiness. First run can take several minutes while models download..."
  deadline=$(( $(date +%s) + 1200 ))
  ready=0
  while [ "$(date +%s)" -lt "$deadline" ]; do
    health=$(curl -fsS http://localhost:8001/health 2>/dev/null || true)
    if printf '%s' "$health" | grep -q '"provider":"ollama"' && printf '%s' "$health" | grep -q '"runtime_ready":true'; then
      ready=1
      break
    fi
    if [ -n "$health" ]; then
      echo "AI health: $health"
    else
      echo "AI health endpoint is not ready yet."
    fi
    sleep 15
  done
  if [ "$ready" -ne 1 ]; then
    echo 'Local AI did not become ready within 20 minutes. Run "docker compose --profile local-ai logs ollama-init ollama ai-service" to inspect model download/startup.' >&2
    exit 1
  fi
fi

echo
echo "Smart Helpdesk is ready."
echo "Customer store:  http://localhost:3000"
echo "Staff workspace: http://localhost:8080"
echo "Backend docs:    http://localhost:8000/api/docs"
echo "AI health:       http://localhost:8001/health"
echo
echo "Stop later with: docker compose down"
