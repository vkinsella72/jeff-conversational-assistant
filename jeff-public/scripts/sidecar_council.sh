#!/usr/bin/env bash
#!/usr/bin/env bash
# sidecar_council.sh — Generic-Jeff pattern: multi-agent council: parallel positions + vote
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

# sidecar_council.sh — Two-model comparison: me (Jeff, inline) vs ${SIDECAR_NAME} (GPT-4o).
# Usage:
#   sidecar_council.sh "question"                 # both models, side by side
#   sidecar_council.sh -f context-file "question" # include context from a file
#   sidecar_council.sh -c "decision"              # council mode: short answer + verdict
#   echo "q" | sidecar_council.sh -               # stdin
#
# Output: both replies, then a synthesis line. Not magic — just structure.

set -euo pipefail

CONTEXT_FILE=""
COUNCIL_MODE=0
TIMEOUT=45

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f) CONTEXT_FILE="$2"; shift 2;;
    -c) COUNCIL_MODE=1; shift;;
    -t) TIMEOUT="$2"; shift 2;;
    -) QUESTION=$(cat); shift;;
    -h|--help)
      sed -n '2,10p' "$0"; exit 0;;
    *) QUESTION="$1"; shift;;
  esac
done

if [[ -z "${QUESTION:-}" ]]; then
  echo "Usage: sidecar_council.sh [-f context.txt] [-c] 'question'" >&2
  exit 2
fi

# Build full question (with context if provided)
if [[ -n "$CONTEXT_FILE" && -f "$CONTEXT_FILE" ]]; then
  FULL_Q="$QUESTION

--- CONTEXT ---
$(cat "$CONTEXT_FILE")
--- END CONTEXT ---"
else
  FULL_Q="$QUESTION"
fi

WRAPPER="$HOME/.openclaw/workspace/scripts/sidecar_query.sh"

echo "════════════════════════════════════════════════════════════════"
echo "  COUNCIL — Two-model comparison"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "QUESTION:"
echo "  $QUESTION"
[[ -n "$CONTEXT_FILE" ]] && echo "  (context: $CONTEXT_FILE)"
echo ""
echo "────────────────────────────────────────────────────────────────"
echo "  JEFF (me) — answering inline below"
echo "────────────────────────────────────────────────────────────────"
echo ""
# Jeff's answer comes from the calling context. The script just frames.
# The orchestrator (Jeff) fills this in via the calling context.
echo "[This is the slot for Jeff's own answer — filled in by the caller]"
echo ""
echo "────────────────────────────────────────────────────────────────"
echo "  SKALES (GPT-4o) — via A2A"
echo "────────────────────────────────────────────────────────────────"
echo ""
SKALES_ANS=$("$WRAPPER" -t "$TIMEOUT" "$FULL_Q" 2>&1) || {
  echo "ERROR: ${SIDECAR_NAME} call failed: $SKALES_ANS" >&2
  exit 3
}
echo "$SKALES_ANS"
echo ""
echo "────────────────────────────────────────────────────────────────"
if [[ "$COUNCIL_MODE" -eq 1 ]]; then
  echo "  VERDICT (synthesised by Jeff in the calling context)"
else
  echo "  SYNTHESIS (compare above — agreements, disagreements, blind spots)"
fi
echo "────────────────────────────────────────────────────────────────"
echo ""
echo "[Verdict slot — Jeff synthesises here in the calling context]"
echo ""
echo "════════════════════════════════════════════════════════════════"
