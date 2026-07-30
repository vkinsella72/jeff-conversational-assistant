#!/usr/bin/env bash
#!/usr/bin/env bash
# sidecar_browse.sh — Generic-Jeff pattern: browser-driven scraping via the sidecar's Codework
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

# sidecar_browse.sh — Hand browser-driven scraping off to ${SIDECAR_NAME}.
#
# When I need a page that requires a real browser (JS-rendered, login-walled,
# interactive), the Jeff-side browser control service might be down, and
# rebuilding it is yak-shaving. This wrapper hands the work to ${SIDECAR_NAME},
# which has a Codework mode designed for exactly this.
#
# Two modes:
#
#   1. CURL FIRST (default)
#      Hit the URL with curl, return whatever HTML/JSON comes back.
#      Works for static pages, JSON APIs, RSS feeds. Fast, free.
#      Set the env var SKIP_CURL=1 to bypass.
#
#   2. SKALES CODEWORK (fallback)
#      When curl returns nothing useful (JS-rendered, login required,
#      interactively-loaded content), this wrapper posts a task to
#      ${SIDECAR_NAME}' Codework runner. Codework can drive a browser, run
#      multi-step tasks, save outputs to a folder.
#
# Usage:
#   sidecar_browse.sh <url> [extract_hint]
#   sidecar_browse.sh --skales <url> <task> <folder>
#
# Examples:
#   sidecar_browse.sh https://api.mixcloud.com/<your-dj-handle>/
#   sidecar_browse.sh https://www.mixcloud.com/<your-dj-handle>/ "Get chart position for each cloudcast"
#   sidecar_browse.sh --skales https://www.mixcloud.com/<your-dj-handle>/ \
#     "Log in as <your-dj-handle> and capture the highest chart position each show has achieved" \
#     ~/Desktop/Jeff\'s\ Notes\ \&\ Projects/Jeff/analyses/
#
# Failsafe:
#   - Curl mode: just returns the page (or curl error)
#   - ${SIDECAR_NAME} mode: same exit-code pattern as sidecar_query.sh
#     - 0 = success, got a response
#     - 3 = ${SIDECAR_NAME} unavailable (graceful: caller carries on)
#     - 4 = API error, 5 = parse, 6 = timeout
#
# What this script is NOT:
#   - It doesn't authenticate to Mixcloud (or anywhere). For login-walled
#     pages, the Codework task needs the credentials baked in or you do it
#     yourself in the ${SIDECAR_NAME} UI.
#   - It doesn't run headless chrome locally. That's the Jeff browser,
#     which is the thing that's broken.
#   - It doesn't auto-retry. Run it again if it fails.

set -euo pipefail

SIDECAR_URL="${SIDECAR_URL:-http://127.0.0.1:3000/api/a2a/message}"
SIDECAR_KEY="${SIDECAR_KEY:?SIDECAR_KEY must be set (see private/wired/ or Jeff's Kitchen/Stuff/API Keys.rtf)}"
SKALES_CODEWORK_URL="${SKALES_CODEWORK_URL:-http://127.0.0.1:3000/api/codework/run}"

usage() {
  cat <<'EOF'
sidecar_browse.sh — browser-driven scraping via ${SIDECAR_NAME} handoff

Usage:
  sidecar_browse.sh [--skales] <url> [task] [folder]

Modes:
  (default)   curl the URL, return content
  --skales    launch a ${SIDECAR_NAME} Codework run for the URL (handles JS pages, logins)

Args:
  url         the page to fetch
  task        (skales mode only) natural-language description of what to extract
  folder      (skales mode only) absolute path to save outputs in

Failsafe:
  Exits 3 if ${SIDECAR_NAME} is unavailable (caller carries on without browser).
  Exits 4 on API error, 5 on parse, 6 on timeout.

Examples:
  sidecar_browse.sh https://api.mixcloud.com/<your-dj-handle>/
  sidecar_browse.sh --skales https://www.mixcloud.com/<your-dj-handle>/ \
    "Capture each cloudcast's highest chart position" \
    ~/Desktop/Jeff's Kitchen/Jeff/analyses/
EOF
}

if [[ $# -lt 1 ]] || [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
  usage
  exit 2
fi

# === Mode: --skales (heavy, browser via Codework) ===
if [[ "${1:-}" == "--skales" ]]; then
  shift
  URL="${1:-}"
  TASK="${2:-}"
  FOLDER="${3:-}"
  if [[ -z "$URL" || -z "$TASK" || -z "$FOLDER" ]]; then
    echo "Usage: sidecar_browse.sh --skales <url> <task> <folder>" >&2
    exit 2
  fi

  # Pre-flight health check (uses sidecar_query.sh cache)
  QUERY="$HOME/.openclaw/workspace/scripts/sidecar_query.sh"
  if ! "$QUERY" --status >/dev/null 2>&1; then
    cat >&2 <<EOF
════════════════════════════════════════════════════════════════
  FAILSAFE: ${SIDECAR_NAME} unavailable — browser handoff skipped
════════════════════════════════════════════════════════════════
  URL:   $URL
  Task:  $TASK
  Folder: $FOLDER

  Without ${SIDECAR_NAME}, I can't drive a browser. Options:
  1. Bring ${SIDECAR_NAME} up
  2. Use the curl mode (drop --skales) for static pages
  3. Do the work yourself in your own browser
════════════════════════════════════════════════════════════════
EOF
    exit 3
  fi

  # Ensure folder exists
  mkdir -p "$FOLDER" || {
    echo "ERROR: cannot create folder: $FOLDER" >&2
    exit 2
  }

  # Build the natural-language task with the URL embedded
  FULL_TASK="Navigate to $URL. $TASK. Save your findings as a markdown file in the folder, including the source URL and date."

  PAYLOAD=$(printf '{"task":%s,"folderPath":%s}' \
    "$(printf '%s' "$FULL_TASK" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
    "$(printf '%s' "$FOLDER" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')")

  echo "=== ${SIDECAR_NAME} Codework run ==="
  echo "  URL:    $URL"
  echo "  Task:   $TASK"
  echo "  Folder: $FOLDER"
  echo "  (streaming progress; Ctrl-C to abort)"
  echo ""

  # SSE stream. -N = no buffering, -m 0 = no timeout
  if curl -sS -N -m 0 -X POST "$SKALES_CODEWORK_URL" \
    -H "Authorization: Bearer $SIDECAR_KEY" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD"; then
    echo ""
    echo "=== Codework run complete. Check $FOLDER for output. ==="
    exit 0
  else
    rc=$?
    echo "ERROR: Codework run failed (exit $rc)" >&2
    exit 4
  fi
fi

# === Mode: curl (default, lightweight) ===
URL="${1:-}"
HINT="${2:-}"

if [[ -z "$URL" ]]; then
  usage >&2
  exit 2
fi

# Quick health check — if curl fails outright, give a clear error
HTTP_CODE=$(curl -sS -m 15 -L -o /tmp/skales_browse_resp_$$ -w "%{http_code}" "$URL" 2>/dev/null) || {
  rc=$?
  if [[ "$rc" == "28" ]]; then
    echo "ERROR: timed out fetching $URL (15s)" >&2
  else
    echo "ERROR: curl failed (exit $rc) for $URL" >&2
  fi
  rm -f /tmp/skales_browse_resp_$$
  exit 3
}

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "ERROR: $URL returned HTTP $HTTP_CODE" >&2
  if [[ -f /tmp/skales_browse_resp_$$ ]]; then
    head -c 500 /tmp/skales_browse_resp_$$ >&2
    echo "" >&2
  fi
  rm -f /tmp/skales_browse_resp_$$
  exit 4
fi

# If HINT is given, surface a one-liner
if [[ -n "$HINT" ]]; then
  SIZE=$(wc -c < /tmp/skales_browse_resp_$$)
  echo "OK: $URL (${SIZE} bytes, HTTP 200) — look for: $HINT" >&2
fi

# Dump content
cat /tmp/skales_browse_resp_$$
rm -f /tmp/skales_browse_resp_$$
exit 0
