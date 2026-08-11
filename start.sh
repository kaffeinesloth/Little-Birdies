#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_DIR="$ROOT_DIR/.smart-helpdesk"
LOG_DIR="$RUNTIME_DIR/logs"
STATE_FILE="$RUNTIME_DIR/processes.env"

SKIP_INSTALL=0
OPEN_BROWSER=0

for arg in "$@"; do
  case "$arg" in
    --skip-install) SKIP_INSTALL=1 ;;
    --open-browser) OPEN_BROWSER=1 ;;
    *)
      echo "Unknown option: $arg" >&2
      echo "Usage: ./start.sh [--skip-install] [--open-browser]" >&2
      exit 2
      ;;
  esac
done

step() {
  printf '\n==> %s\n' "$1"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "$1 was not found. Install it and make sure it is on PATH." >&2
    exit 1
  fi
}

port_available() {
  local port="$1"
  if command -v lsof >/dev/null 2>&1 && lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "Port $port is already in use. Stop that process or change the project port." >&2
    exit 1
  fi
}

stop_started() {
  if [[ -n "${WEB_PID:-}" ]]; then kill "$WEB_PID" >/dev/null 2>&1 || true; fi
  if [[ -n "${API_PID:-}" ]]; then kill "$API_PID" >/dev/null 2>&1 || true; fi
  if [[ -n "${AI_PID:-}" ]]; then kill "$AI_PID" >/dev/null 2>&1 || true; fi
}

state_has_live_processes() {
  # shellcheck disable=SC1090
  source "$STATE_FILE"
  for pid in "${WEB_PID:-}" "${API_PID:-}" "${AI_PID:-}"; do
    if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
      return 0
    fi
  done
  return 1
}

start_detached() {
  local dir="$1"
  local stdout_path="$2"
  local stderr_path="$3"
  shift 3

  nohup bash -c 'cd "$1"; shift; exec "$@"' _ "$dir" "$@" \
    >"$stdout_path" 2>"$stderr_path" &
  printf '%s\n' "$!"
}

wait_for_health() {
  local name="$1"
  local url="$2"
  local pid="$3"
  local timeout="${4:-60}"
  local deadline=$((SECONDS + timeout))

  while (( SECONDS < deadline )); do
    if ! kill -0 "$pid" >/dev/null 2>&1; then
      echo "$name stopped during startup." >&2
      return 1
    fi
    if curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.5
  done

  echo "$name did not become ready within ${timeout}s." >&2
  return 1
}

ensure_python_service() {
  local dir="$1"
  local import_check="$2"
  local python_bin="$dir/.venv/bin/python"

  if [[ ! -x "$python_bin" ]]; then
    if (( SKIP_INSTALL )); then
      echo "Missing Python environment in $dir. Run ./start.sh without --skip-install first." >&2
      exit 1
    fi
    step "Creating Python environment for $dir"
    python3 -m venv "$dir/.venv"
  fi

  if ! "$python_bin" -c "$import_check" >/dev/null 2>&1; then
    if (( SKIP_INSTALL )); then
      echo "Python dependencies are missing in $dir. Run ./start.sh without --skip-install first." >&2
      exit 1
    fi
    step "Installing Python dependencies for $dir"
    "$python_bin" -m pip install -r "$dir/requirements.txt"
  fi

  printf '%s\n' "$python_bin"
}

if [[ -f "$STATE_FILE" ]]; then
  if state_has_live_processes; then
    echo "Smart Helpdesk appears to be running already. Use ./stop.sh before starting again." >&2
    exit 1
  fi
  rm -f "$STATE_FILE"
fi

trap stop_started ERR INT TERM

require_command python3
require_command curl
require_command flutter

mkdir -p "$LOG_DIR"
port_available 3000
port_available 8000
port_available 8001

AI_DIR="$ROOT_DIR/backend/ai"
API_DIR="$ROOT_DIR/backend/api"
WEB_DIR="$ROOT_DIR/web"

AI_PYTHON="$(ensure_python_service "$AI_DIR" 'import fastapi, uvicorn, pydantic_settings, httpx, chromadb, pypdf, docx')"
API_PYTHON="$(ensure_python_service "$API_DIR" 'import fastapi, uvicorn, pydantic_settings, httpx, jwt, multipart')"

if [[ ! -f "$WEB_DIR/.dart_tool/package_config.json" ]]; then
  if (( SKIP_INSTALL )); then
    echo "Flutter web dependencies are missing. Run ./start.sh without --skip-install first." >&2
    exit 1
  fi
  step "Installing Flutter web dependencies"
  (cd "$WEB_DIR" && flutter pub get)
fi

step "Starting AI service on http://127.0.0.1:8001"
AI_PID="$(start_detached "$AI_DIR" "$LOG_DIR/ai.out.log" "$LOG_DIR/ai.err.log" \
  env APP_ENV=development RAG_CONFIDENCE_THRESHOLD=0.0 CHROMA_DB_PATH="$AI_DIR/chroma" \
  "$AI_PYTHON" -m uvicorn app.main:app --host 127.0.0.1 --port 8001)"
wait_for_health "AI service" "http://127.0.0.1:8001/health" "$AI_PID" 90

step "Starting backend API on http://127.0.0.1:8000"
API_PID="$(start_detached "$API_DIR" "$LOG_DIR/api.out.log" "$LOG_DIR/api.err.log" \
  env APP_ENV=development LOCAL_MOCK_AUTH_ENABLED=true LOCAL_MOCK_DB_ENABLED=true AI_SERVICE_URL=http://127.0.0.1:8001 \
  "$API_PYTHON" -m uvicorn app.main:app --host 127.0.0.1 --port 8000)"
wait_for_health "Backend API" "http://127.0.0.1:8000/health" "$API_PID" 90

step "Starting Flutter web on http://127.0.0.1:3000"
WEB_PID="$(start_detached "$WEB_DIR" "$LOG_DIR/web.out.log" "$LOG_DIR/web.err.log" \
  flutter run -d web-server \
  --web-hostname 127.0.0.1 \
  --web-port 3000 \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000)"
wait_for_health "Flutter web" "http://127.0.0.1:3000" "$WEB_PID" 120

cat >"$STATE_FILE" <<EOF
AI_PID=$AI_PID
API_PID=$API_PID
WEB_PID=$WEB_PID
EOF

trap - ERR INT TERM

printf '\nSmart Helpdesk is running.\n'
printf 'Web:     http://127.0.0.1:3000\n'
printf 'API:     http://127.0.0.1:8000/health\n'
printf 'AI:      http://127.0.0.1:8001/health\n'
printf 'Account: owner@example.com / password\n'
printf 'Logs:    %s\n' "$LOG_DIR"
printf 'Stop:    ./stop.sh\n'

if (( OPEN_BROWSER )); then
  open "http://127.0.0.1:3000" >/dev/null 2>&1 || true
fi
