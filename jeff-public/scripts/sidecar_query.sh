#!/usr/bin/env bash
# sidecar_query.sh — Jeff's wrapper around a *local* reasoning sidecar.
#
# PATTERN: This is the *shape* of how you call a local LLM sidecar (any app
# that speaks A2A or OpenAI-compat over HTTP) for second-opinion reasoning.
# The example instance was Skales (the original Jeff's set-up), but the same script
# works against LM Studio, Open WebUI, or anything with a local A2A endpoint.
#
# Failsafe behaviour:
#   - Pre-flight health check (cached 60s) — if the sidecar is down, fail fast
#   - Clear error messages with distinct exit codes (3=down, 4=api-error, 5=parse, 6=timeout)
#   - --no-failsafe flag to bypass health check (for testing)
#   - --status flag to check health without sending a request
#
# Usage:
#   sidecar_query.sh "prompt"                  # one-shot, prints reply
#   sidecar_query.sh -i conv-id "prompt"       # conversation label (not a real thread)
#   sidecar_query.sh -t 90 "prompt"            # custom timeout seconds
#   sidecar_query.sh -j "prompt"               # raw JSON response
#   sidecar_query.sh --status                  # health check, exit 0=up, 3=down
#   sidecar_query.sh --no-failsafe "prompt"    # skip the health check
#   echo "prompt" | sidecar_query.sh -         # stdin
#
# Env overrides:
#   SIDECAR_URL       (default http://127.0.0.1:3000/api/a2a/message)
#   SIDECAR_NAME      (default "the sidecar" — used in user-facing messages)
#   SIDECAR_KEY       (Bearer token; set per your sidecar)
#   SIDECAR_HEALTH_TTL (default 60s; how long to cache health result)
#   SIDECAR_AGENT_PATH (default "/api/a2a/agent-card" — discovery endpoint)
#
# To adapt: copy this script, set SIDECAR_URL and SIDECAR_KEY for your app,
# and the same code path works.

set -euo pipefail

SIDECAR_URL="${SIDECAR_URL:-http://127.0.0.1:3000/api/a2a/message}"
SIDECAR_KEY="${SIDECAR_KEY:?SIDECAR_KEY must be set (see the principal's API keys file (commonly `~/Stuff/API Keys.rtf`))}"
SIDECAR_HEALTH_CACHE="${TMPDIR:-/tmp}/sidecar_health_$$"
SIDECAR_HEALTH_TTL="${SIDECAR_HEALTH_TTL:-60}"

TIMEOUT=60
CONV_ID="jeff-$(date +%s)-$RANDOM"
RAW_JSON=0
SKIP_HEALTH=0
SIDECAR_NAME="${SIDECAR_NAME:-the sidecar}"
STATUS_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i) CONV_ID="$2"; shift 2;;
    -t) TIMEOUT="$2"; shift 2;;
    -j) RAW_JSON=1; shift;;
    --no-failsafe) SKIP_HEALTH=1; shift;;
    --status) STATUS_ONLY=1; shift;;
    -) PROMPT=$(cat); shift;;
    -h|--help)
      sed -n '2,22p' "$0"; exit 0;;
    *) PROMPT="$1"; shift;;
  esac
done

# Health check with TTL cache. Returns 0 if up, 3 if down.
sidecar_health() {
  local card_url="${SIDECAR_URL%/message}/agent-card"
  local now
  now=$(date +%s)
  if [[ -f "$SIDECAR_HEALTH_CACHE" ]]; then
    local age=$(( now - $(stat -f%m "$SIDECAR_HEALTH_CACHE" 2>/dev/null || echo 0) ))
    if [[ "$age" -lt "$SIDECAR_HEALTH_TTL" ]]; then
      local cached
      cached=$(cat "$SIDECAR_HEALTH_CACHE")
      if [[ "$cached" == "up" ]]; then return 0; else return 3; fi
    fi
  fi

  # Try the agent card (no auth required). 2s budget.
  local code
  code=$(curl -sS -m 2 -o /dev/null -w "%{http_code}" "$card_url" 2>/dev/null || echo "000")
  if [[ "$code" == "200" ]]; then
    echo "up" > "$SIDECAR_HEALTH_CACHE"
    return 0
  else
    echo "down:$code" > "$SIDECAR_HEALTH_CACHE"
    return 3
  fi
}

# --status short-circuit
if [[ "$STATUS_ONLY" -eq 1 ]]; then
  SKIP_HEALTH=1  # always do a fresh check on --status
  if sidecar_health; then
    echo "${SIDECAR_NAME}: UP (${SIDECAR_URL})"
    exit 0
  else
    echo "${SIDECAR_NAME}: DOWN (${SIDECAR_URL})" >&2
    exit 3
  fi
fi

# Pre-flight failsafe
if [[ "$SKIP_HEALTH" -eq 0 ]]; then
  if ! skales_health; then
    cat >&2 <<EOF
ERROR: Skales is unavailable. Failsafe triggered.

Endpoint: ${SIDECAR_URL}
Cache TTL: ${SIDECAR_HEALTH_TTL}s
Bypass:   use --no-failsafe to skip this check
Status:   run --status to re-check

Carry on without Skales. I lose second-opinion reasoning for this call.
The decision and the action are still mine to make.
EOF
    exit 3
  fi
fi

if [[ -z "${PROMPT:-}" ]]; then
  echo "Usage: skales_query.sh [--status] [--no-failsafe] [-i conv-id] [-t seconds] [-j] 'prompt'" >&2
  exit 2
fi

# Build payload with a stable conversation id so multi-turn context works
PAYLOAD=$(printf '{"id":"%s","message":"%s"}' \
  "$CONV_ID" \
  "$(printf '%s' "$PROMPT" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//')")

# Capture HTTP code separately so we can distinguish timeout (curl exit 28) from API errors
HTTP_CODE=$(curl -sS -m "$TIMEOUT" -o /tmp/sidecar_resp_$$ -w "%{http_code}" -X POST "$SIDECAR_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $SIDECAR_KEY" \
  -d "$PAYLOAD" 2>/dev/null) || {
    rc=$?
    if [[ "$rc" == "28" ]]; then
      echo "ERROR: Skales timed out after ${TIMEOUT}s" >&2
      rm -f /tmp/sidecar_resp_$$
      exit 6
    fi
    echo "ERROR: curl failed (exit $rc)" >&2
    rm -f /tmp/sidecar_resp_$$
    exit 3
  }

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "ERROR: Skales returned HTTP $HTTP_CODE" >&2
  cat /tmp/sidecar_resp_$$ >&2
  rm -f /tmp/sidecar_resp_$$
  exit 4
fi

RESP=$(cat /tmp/sidecar_resp_$$)
rm -f /tmp/sidecar_resp_$$

if [[ "$RAW_JSON" -eq 1 ]]; then
  printf '%s\n' "$RESP"
  exit 0
fi

# Try to extract just the agent's reply text
TEXT=$(printf '%s' "$RESP" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    if "error" in data:
        print("ERROR:", data["error"], file=sys.stderr); sys.exit(4)
    parts = (data.get("result") or data.get("message") or {}).get("parts") or []
    out = "".join(p.get("text","") for p in parts if p.get("kind")=="text" or "text" in p)
    print(out if out else json.dumps(data, indent=2))
except Exception as e:
    print("ERROR parsing response:", e, file=sys.stderr)
    print(sys.stdin.read(), file=sys.stderr); sys.exit(5)
')

printf '%s\n' "$TEXT"
