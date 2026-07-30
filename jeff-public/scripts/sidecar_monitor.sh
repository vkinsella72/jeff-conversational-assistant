#!/usr/bin/env bash
#!/usr/bin/env bash
# sidecar_monitor.sh — Generic-Jeff pattern: read-only monitor of the sidecar's internal API
#
# ADAPTED FROM: the original Jeff's sidecar integration. The original was tied to
# the ${SIDECAR_NAME} desktop app; this version treats it as a *local sidecar* — any
# LLM that exposes an A2A / OpenAI-compat endpoint over HTTP. Same code path
# works against ${SIDECAR_NAME}, LM Studio, Open WebUI, or anything with the same shape.
#
# To use: set SIDECAR_URL, SIDECAR_KEY, SIDECAR_NAME in your env, or override
# the defaults. Run --help for usage.
#
# The patterns demonstrated here (failsafe health check, distinct exit codes,
# graceful delegation, weekly state-change alert) are the real value. Fork and
# adapt — the brand is less important than the failsafe contract.
#
# Original behaviour follows below.

# sidecar_monitor.sh — Read and control ${SIDECAR_NAME}' internal task/multi-agent API.
# This is the "observability" arm of the ${SIDECAR_NAME} integration.
# It uses the same bearer key as sidecar_query.sh and the same failsafe pattern.
#
# Usage:
#   sidecar_monitor.sh status                    # overall health
#   sidecar_monitor.sh current-task              # what the multi-agent org is doing now
#   sidecar_monitor.sh agent-sync                # swarm status
#   sidecar_monitor.sh activity [N]              # last N activity events (default 20)
#   sidecar_monitor.sh workflows                 # saved workflows
#   sidecar_monitor.sh skills [active|custom]    # active skills list
#   sidecar_monitor.sh dreaming                  # dreaming diary
#   sidecar_monitor.sh buddy-activity            # buddy activity
#   sidecar_monitor.sh dashboard                 # dashboard notifications
#   sidecar_monitor.sh abort <taskId>            # abort a running multi-agent task
#   sidecar_monitor.sh approve <taskId>          # approve a pending task
#   sidecar_monitor.sh raw <path>                # raw GET against any /api/... path
#   sidecar_monitor.sh call <METHOD> <path> [json] # raw method+path with optional body
#   sidecar_monitor.sh --routes                  # dump the discovered route table
#
# Failsafe: same health check + exit codes as sidecar_query.sh.
# Exit codes: 0=ok, 2=usage, 3=down, 4=api-error, 5=parse, 6=timeout

set -euo pipefail

SKALES_BASE="${SKALES_BASE:-http://127.0.0.1:3000}"
SIDECAR_KEY="${SIDECAR_KEY:?SIDECAR_KEY must be set (see private/wired/ or Jeff's Kitchen/Stuff/API Keys.rtf)}"
SKALES_HEALTH_CACHE="${TMPDIR:-/tmp}/skales_monitor_health_$$"
SKALES_HEALTH_TTL="${SKALES_HEALTH_TTL:-60}"
TIMEOUT="${SKALES_MON_TIMEOUT:-15}"

# Discovered route table (verified 2026-06-09 against ${SIDECAR_NAME} v11.2.0)
# Read-write: get|abort|approve
ROUTES_READ=(
  "status|GET|/api/health"
  "current-task|GET|/api/organization/current-task"
  "agent-sync|GET|/api/agent-sync/status"
  "activity|GET|/api/activity/log"
  "workflows|GET|/api/workflows"
  "skills|GET|/api/skills/active"
  "custom-skills|GET|/api/custom-skills/active"
  "dreaming|GET|/api/dreaming"
  "buddy-activity|GET|/api/buddy/activity"
  "buddy-memory|GET|/api/buddy-memory"
  "dashboard|GET|/api/dashboard-notifications"
  "health|GET|/api/health"
  "tags|GET|/api/tags"
)
ROUTES_WRITE_ABORT="POST|/api/organization/abort"
ROUTES_WRITE_APPROVE="POST|/api/organization/approval"

skales_health() {
  local card_url="${SKALES_BASE}/api/a2a/agent-card"
  local now
  now=$(date +%s)
  if [[ -f "$SKALES_HEALTH_CACHE" ]]; then
    local age=$(( now - $(stat -f%m "$SKALES_HEALTH_CACHE" 2>/dev/null || echo 0) ))
    if [[ "$age" -lt "$SKALES_HEALTH_TTL" ]]; then
      local cached
      cached=$(cat "$SKALES_HEALTH_CACHE")
      if [[ "$cached" == "up" ]]; then return 0; else return 3; fi
    fi
  fi
  local code
  code=$(curl -sS -m 2 -o /dev/null -w "%{http_code}" "$card_url" 2>/dev/null || echo "000")
  if [[ "$code" == "200" ]]; then
    echo "up" > "$SKALES_HEALTH_CACHE"
    return 0
  else
    echo "down:$code" > "$SKALES_HEALTH_CACHE"
    return 3
  fi
}

# Build a route lookup table once
route_for() {
  local alias="$1"
  local r
  for r in "${ROUTES_READ[@]}"; do
    IFS='|' read -r name method path <<< "$r"
    if [[ "$name" == "$alias" ]]; then
      echo "${method}|${path}"
      return 0
    fi
  done
  return 1
}

usage() {
  cat <<EOF
sidecar_monitor.sh — Read/control ${SIDECAR_NAME}' internal task API.

Read:
  status                    health + connected bots
  current-task              multi-agent org's current task (null if idle)
  agent-sync                swarm status and peers
  activity [N]              last N activity events (default 20)
  workflows                 saved workflows list
  skills [active|custom]    active skills (default: active)
  dreaming                  dreaming diary
  buddy-activity            buddy activity
  dashboard                 dashboard notifications
  tags                      available tags

Write:
  abort <taskId>            abort a running multi-agent task
  approve <toolCallId> [approved]  approve/reject a pending tool call
  codework-run <task> <folder>  launch a Codework run (streams SSE)
  ollama-pull <model>        pull a model into Ollama (via ${SIDECAR_NAME})
  swarm-start                start a multi-agent swarm (may be disabled)

Raw:
  raw <path>                raw GET /api/...
  call <METHOD> <path> [json]  raw request with optional JSON body
  --routes                  dump the discovered route table

Failsafe:
  - pre-flight health check (60s TTL cache, override with SKALES_HEALTH_TTL=0)
  - distinct exit codes (0=ok, 3=down, 4=api-error, 5=parse, 6=timeout)
  - SKALES_BASE and SIDECAR_KEY env vars to override defaults
EOF
}

# === MAIN ===
CMD="${1:-}"
shift || true

if [[ -z "$CMD" || "$CMD" == "-h" || "$CMD" == "--help" ]]; then
  usage
  exit 2
fi

# --routes: dump the table and exit
if [[ "$CMD" == "--routes" ]]; then
  echo "Discovered ${SIDECAR_NAME} routes (verified 2026-06-09, v11.2.0):"
  printf '  %-18s %-6s %s\n' "ALIAS" "METHOD" "PATH"
  printf '  %-18s %-6s %s\n' "----" "------" "----"
  for r in "${ROUTES_READ[@]}"; do
    IFS='|' read -r name method path <<< "$r"
    printf '  %-18s %-6s %s\n' "$name" "$method" "$path"
  done
  echo ""
  echo "Write routes:"
  printf '  %-18s %-6s %s\n' "abort" "POST" "${ROUTES_WRITE_ABORT#POST|}"
  printf '  %-18s %-6s %s\n' "approve" "POST" "${ROUTES_WRITE_APPROVE#POST|}"
  printf '  %-18s %-6s %s\n' "codework-run" "POST" "/api/codework/run (SSE)"
  printf '  %-18s %-6s %s\n' "ollama-pull" "POST" "/api/ollama/pull"
  printf '  %-18s %-6s %s\n' "swarm-start" "POST" "/api/agent-sync/start-swarm"
  echo ""
  echo "Body shapes:"
  echo "  abort:    no body required"
  echo "  approve:  body requires toolCallId (and optionally toolName/agentId/approved)"
  echo "  codework-run: { task, folderPath } — streams progress"
  echo "  ollama-pull:  { model }"
  echo "  swarm-start:  {} (may be disabled by config)"
  exit 0
fi

# All real commands need ${SIDECAR_NAME} to be up
if ! skales_health; then
  cat >&2 <<EOF
ERROR: ${SIDECAR_NAME} is unavailable. Failsafe triggered.
Endpoint: ${SKALES_BASE}
Cache TTL: ${SKALES_HEALTH_TTL}s
Bypass:   SKALES_HEALTH_TTL=0 sidecar_monitor.sh ...
Status:   sidecar_query.sh --status
Carry on without observability.
EOF
  exit 3
fi

# Helper: GET an API path, pretty-print JSON, with proper error handling
api_get() {
  local path="$1"
  local body code
  code=$(curl -sS -m "$TIMEOUT" -o /tmp/skales_mon_resp_$$ -w "%{http_code}" \
    -H "Authorization: Bearer $SIDECAR_KEY" \
    -H "Content-Type: application/json" \
    "${SKALES_BASE}${path}" 2>/dev/null) || {
      rc=$?
      if [[ "$rc" == "28" ]]; then
        echo "ERROR: timed out after ${TIMEOUT}s on GET ${path}" >&2
        rm -f /tmp/skales_mon_resp_$$
        exit 6
      fi
      echo "ERROR: curl failed (exit $rc) on GET ${path}" >&2
      rm -f /tmp/skales_mon_resp_$$
      exit 3
    }
  if [[ "$code" != "200" ]]; then
    echo "ERROR: HTTP $code on GET ${path}" >&2
    cat /tmp/skales_mon_resp_$$ >&2
    rm -f /tmp/skales_mon_resp_$$
    exit 4
  fi
  body=$(cat /tmp/skales_mon_resp_$$)
  rm -f /tmp/skales_mon_resp_$$
  if command -v jq >/dev/null 2>&1; then
    echo "$body" | jq . 2>/dev/null || echo "$body"
  else
    echo "$body" | python3 -m json.tool 2>/dev/null || echo "$body"
  fi
}

# Helper: POST a body (or empty)
api_post() {
  local path="$1"
  local body="${2:-}"
  local code rc
  if [[ -n "$body" ]]; then
    code=$(curl -sS -m "$TIMEOUT" -o /tmp/skales_mon_resp_$$ -w "%{http_code}" \
      -X POST \
      -H "Authorization: Bearer $SIDECAR_KEY" \
      -H "Content-Type: application/json" \
      -d "$body" \
      "${SKALES_BASE}${path}" 2>/dev/null) || rc=$?
  else
    code=$(curl -sS -m "$TIMEOUT" -o /tmp/skales_mon_resp_$$ -w "%{http_code}" \
      -X POST \
      -H "Authorization: Bearer $SIDECAR_KEY" \
      -H "Content-Type: application/json" \
      "${SKALES_BASE}${path}" 2>/dev/null) || rc=$?
  fi
  if [[ "${rc:-0}" == "28" ]]; then
    echo "ERROR: timed out after ${TIMEOUT}s on POST ${path}" >&2
    rm -f /tmp/skales_mon_resp_$$
    exit 6
  fi
  if [[ -n "${rc:-}" ]] && [[ "$code" == "000" ]]; then
    echo "ERROR: curl failed (exit $rc) on POST ${path}" >&2
    rm -f /tmp/skales_mon_resp_$$
    exit 3
  fi
  if [[ "$code" != "200" && "$code" != "201" && "$code" != "204" ]]; then
    echo "ERROR: HTTP $code on POST ${path}" >&2
    cat /tmp/skales_mon_resp_$$ >&2
    rm -f /tmp/skales_mon_resp_$$
    exit 4
  fi
  local resp
  resp=$(cat /tmp/skales_mon_resp_$$)
  rm -f /tmp/skales_mon_resp_$$
  if [[ -n "$resp" ]]; then
    if command -v jq >/dev/null 2>&1; then
      echo "$resp" | jq . 2>/dev/null || echo "$resp"
    else
      echo "$resp" | python3 -m json.tool 2>/dev/null || echo "$resp"
    fi
  else
    echo "(empty response, HTTP $code)"
  fi
}

# Dispatch
case "$CMD" in
  status|health)
    api_get "/api/health"
    ;;
  current-task)
    echo "=== Multi-agent org: current task ==="
    api_get "/api/organization/current-task"
    ;;
  agent-sync)
    echo "=== Agent-sync / swarm status ==="
    api_get "/api/agent-sync/status"
    ;;
  activity)
    N="${1:-20}"
    echo "=== Last $N activity events ==="
    api_get "/api/activity/log" | head -c $((N * 400))
    echo ""
    ;;
  workflows)
    echo "=== Saved workflows ==="
    api_get "/api/workflows"
    ;;
  skills)
    KIND="${1:-active}"
    case "$KIND" in
      active)   api_get "/api/skills/active";;
      custom)   api_get "/api/custom-skills/active";;
      *) echo "Usage: skills [active|custom]" >&2; exit 2;;
    esac
    ;;
  dreaming)
    echo "=== Dreaming diary ==="
    api_get "/api/dreaming"
    ;;
  buddy-activity)
    echo "=== Buddy activity ==="
    api_get "/api/buddy/activity"
    ;;
  dashboard)
    echo "=== Dashboard notifications ==="
    api_get "/api/dashboard-notifications"
    ;;
  tags)
    api_get "/api/tags"
    ;;
  raw)
    PATH_ARG="${1:-}"
    if [[ -z "$PATH_ARG" ]]; then
      echo "Usage: raw <path>  (e.g. raw /api/health)" >&2
      exit 2
    fi
    api_get "$PATH_ARG"
    ;;
  call)
    METHOD="${1:-GET}"
    PATH_ARG="${2:-}"
    BODY="${3:-}"
    if [[ -z "$PATH_ARG" ]]; then
      echo "Usage: call <METHOD> <path> [json-body]" >&2
      exit 2
    fi
    case "$METHOD" in
      GET) api_get "$PATH_ARG";;
      POST) api_post "$PATH_ARG" "$BODY";;
      *) echo "Method $METHOD not pre-built. Use raw GET or call POST." >&2; exit 2;;
    esac
    ;;
  abort)
    # API expects: no body required
    TASK_ID="${1:-}"
    if [[ -z "$TASK_ID" ]]; then
      echo "Usage: abort <taskId>" >&2
      exit 2
    fi
    echo "=== Aborting task $TASK_ID ==="
    api_post "/api/organization/abort" "{\"taskId\":\"$TASK_ID\"}"
    ;;

  # === CONTROL: launch a Codework run (streams SSE) ===
  # Body: { task: "string", folderPath: "string" }
  # Returns: text/event-stream of progress (analyzing → context → plan → steps...)
  codework-run)
    TASK="${1:-}"
    FOLDER="${2:-}"
    if [[ -z "$TASK" || -z "$FOLDER" ]]; then
      cat >&2 <<EOF
Usage: codework-run <task> <folderPath>
  task:       natural language description of what to build/fix
  folderPath: absolute path to the project folder
Streams progress events. Press Ctrl-C to abort.

Example:
  sidecar_monitor.sh codework-run "Add a logout button" ~/Projects/myapp
EOF
      exit 2
    fi
    echo "=== Starting Codework run ==="
    echo "  task: $TASK"
    echo "  folder: $FOLDER"
    echo ""
    # SSE stream - no timeout
    curl -sS -N -m 0 -X POST "http://127.0.0.1:3000/api/codework/run" \
      -H "Authorization: Bearer $SIDECAR_KEY" \
      -H "Content-Type: application/json" \
      -d "$(printf '{"task":"%s","folderPath":"%s"}' "$TASK" "$FOLDER")"
    ;;

  # === CONTROL: pull a model into Ollama (managed by ${SIDECAR_NAME}) ===
  ollama-pull)
    MODEL="${1:-}"
    if [[ -z "$MODEL" ]]; then
      echo "Usage: ollama-pull <model-name>" >&2
      echo "  Example: ollama-pull llama3" >&2
      exit 2
    fi
    echo "=== Pulling Ollama model: $MODEL ==="
    api_post "/api/ollama/pull" "{\"model\":\"$MODEL\"}"
    ;;

  # === CONTROL: start a multi-agent swarm (currently disabled) ===
  swarm-start)
    echo "=== Attempting to start multi-agent swarm ==="
    api_post "/api/agent-sync/start-swarm" "{}"
    ;;
  approve)
    # API expects { toolName, agentId, toolCallId, approved }
    # These come from the current-task's approval_required step.
    # Use `call` for full control: sidecar_monitor.sh call POST /api/organization/approval '{"toolName":"...","agentId":"...","toolCallId":"...","approved":true}'
    TOOL_CALL_ID="${1:-}"
    APPROVE_VALUE="${2:-true}"
    if [[ -z "$TOOL_CALL_ID" ]]; then
      cat >&2 <<EOF
Usage: approve <toolCallId> [approved]
  approved: true|false (default true)

The toolCallId comes from the current-task output (approval_required step).
For full control over the body, use: call POST /api/organization/approval '<json>'
EOF
      exit 2
    fi
    echo "=== Approving toolCallId $TOOL_CALL_ID (approved=$APPROVE_VALUE) ==="
    # The simpler 'approved' call — toolName/agentId are recorded in the task state
    api_post "/api/organization/approval" "{\"toolCallId\":\"$TOOL_CALL_ID\",\"approved\":$APPROVE_VALUE}"
    ;;
  *)
    echo "Unknown command: $CMD" >&2
    usage
    exit 2
    ;;
esac
