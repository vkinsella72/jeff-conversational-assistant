#!/usr/bin/env bash
#!/usr/bin/env bash
# sidecar_ask.sh — Generic-Jeff pattern: graceful delegation (carry on if down)
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

# sidecar_ask.sh — "Ask ${SIDECAR_NAME} if available, else carry on."
#
# This is the FAILSAFE for delegation. The calling agent (Jeff) runs
# reasoning tasks through this. If ${SIDECAR_NAME} is up, gets a second opinion.
# If ${SIDECAR_NAME} is down, the script logs the failure and exits non-zero,
# but Jeff's own logic carries on — the decision and the action are
# still his.
#
# Usage:
#   sidecar_ask.sh "prompt"            # ask if up, else exit 3
#   sidecar_ask.sh --required "prompt" # same, but tag as required
#
# Behaviour:
#   - Calls sidecar_query.sh with health check
#   - On success: prints ${SIDECAR_NAME} reply
#   - On failure: prints failsafe notice to stderr, exits 3
#   - Caller (Jeff) is expected to: read the notice, decide, carry on
#
# This script does NOT auto-degrade to a different model. That's
# the caller's job. The whole point: when the sidecar is gone,
# the principal carries on without it.

set -euo pipefail

WRAPPER="$HOME/.openclaw/workspace/scripts/sidecar_query.sh"

if [[ $# -lt 1 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
  echo "Usage: sidecar_ask.sh [--required] 'prompt'"
  echo "  Returns ${SIDECAR_NAME} reply on success."
  echo "  Exits 3 with a failsafe notice on failure (caller carries on)."
  exit 2
fi

LABEL=""
if [[ "${1:-}" == "--required" ]]; then
  LABEL="[REQUIRED] "
  shift
fi

PROMPT="${1:-}"
if [[ -z "$PROMPT" ]]; then
  echo "Usage: sidecar_ask.sh [--required] 'prompt'" >&2
  exit 2
fi

# Try the call
if OUTPUT=$("$WRAPPER" -t 60 "$PROMPT" 2>&1); then
  printf '%s' "$OUTPUT"
  exit 0
fi

RC=$?
cat >&2 <<EOF
════════════════════════════════════════════════════════════════
  FAILSAFE: ${SIDECAR_NAME} unavailable (exit $RC)
════════════════════════════════════════════════════════════════
  Prompt was: $LABEL$(echo "$PROMPT" | head -c 200)...
  
  This is a graceful-degradation notice, not a stop signal.
  The decision and the action remain with the principal (Jeff).
  
  Carry on. Reason it out. The memory vault has ${SIDECAR_NAME}' schema
  preserved in TOOLS.md if you need to migrate to another tool.
════════════════════════════════════════════════════════════════
EOF
exit 3
