#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$ROOT_DIR/.smart-helpdesk/processes.env"

if [[ ! -f "$STATE_FILE" ]]; then
  echo "Smart Helpdesk is not running, or it was not started with ./start.sh."
  exit 0
fi

set -a
# shellcheck source=/dev/null
source "$STATE_FILE"
set +a

stopped=0
for pid in "${WEB_PID:-}" "${API_PID:-}" "${AI_PID:-}"; do
  if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
    kill "$pid" >/dev/null 2>&1 || true
    stopped=$((stopped + 1))
  fi
done

rm -f "$STATE_FILE"
echo "Smart Helpdesk stopped. $stopped process(es) signaled."
