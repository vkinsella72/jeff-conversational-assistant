#!/usr/bin/env bash
#!/usr/bin/env bash
# sidecar_healthcheck.sh — Generic-Jeff pattern: weekly sidecar health check + state-change alert
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

# sidecar_healthcheck.sh — Weekly health check for ${SIDECAR_NAME}.
# Writes a one-line status to memory/sidecar_health.log
# If status changed since last check, writes an alert to memory/vault/alerts.log
#
# Cron: 0 9 * * 1  (Mondays 9am UK time)

set -euo pipefail

LOG="$HOME/.openclaw/workspace/memory/sidecar_health.log"
ALERTS="$HOME/.openclaw/workspace/memory/vault/alerts.log"
WRAPPER="$HOME/.openclaw/workspace/scripts/sidecar_query.sh"

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Get current status (always fresh, no cache)
if "$WRAPPER" --status >/dev/null 2>&1; then
  STATUS="up"
else
  STATUS="down"
fi

# Get previous status (last non-empty line)
PREV=""
if [[ -f "$LOG" ]]; then
  PREV=$(grep -E "^[0-9]{4}-" "$LOG" | tail -1 | awk '{print $2}')
fi

# Log this run (with monotonic sort key)
TS_FILE=$(mktemp)
sort -o "$LOG" "$LOG" 2>/dev/null || true
echo "$NOW $STATUS" >> "$LOG"
rm -f "$TS_FILE"

# Alert on state change
if [[ -n "$PREV" && "$PREV" != "$STATUS" ]]; then
  echo "$NOW STATE-CHANGE: $PREV -> $STATUS" >> "$ALERTS"
  # Also write a one-shot daily-memory note so next session sees it
  NOTE="$HOME/.openclaw/workspace/memory/SKALES-HEALTH-$(date +%Y-%m-%d).md"
  cat > "$NOTE" <<EOF
# ${SIDECAR_NAME} health alert — $(date +%Y-%m-%d)

**State change detected:** $PREV → $STATUS

If $STATUS == "down":
- ${SIDECAR_NAME} wrapper will exit 3 on every call
- Jeff continues reasoning on his own
- Check: \`curl -sS -m 2 -o /dev/null -w "%{http_code}" http://127.0.0.1:3000/api/a2a/agent-card\`
- Check app: \`ps -ax | grep -i skales | grep -v grep\`
- Recovery: restart ${SIDECAR_NAME} app, then \`~/.openclaw/workspace/scripts/sidecar_query.sh --status\`
EOF
fi

# Trim log to last 200 entries (keep ~4 years of weekly data)
if [[ -f "$LOG" ]] && [[ $(wc -l < "$LOG") -gt 200 ]]; then
  tail -200 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi
