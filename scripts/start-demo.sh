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

sh "$PROJECT_ROOT/scripts/demo-doctor.sh"

if [ "$LOCAL_AI" -eq 1 ]; then
  set -- compose --profile local-ai up --detach --wait
else
  set -- compose up --detach --wait
fi

if [ "$NO_BUILD" -eq 0 ]; then
  set -- "$@" --build
fi

docker "$@"

echo
echo "Smart Helpdesk is ready."
echo "Customer store:  http://localhost:3000"
echo "Staff workspace: http://localhost:8080"
echo "Backend docs:    http://localhost:8000/api/docs"
echo "AI health:       http://localhost:8001/health"
echo
echo "Stop later with: docker compose down"
