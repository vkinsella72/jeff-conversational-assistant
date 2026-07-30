# TOOLS.md - Local Notes

Skills define _how_ tools work. This file is for _your_ specifics — the stuff that's unique to your setup.

## What Goes Here

Things like:

- Camera names and locations
- SSH hosts and aliases
- Preferred voices for TTS
- Speaker/room names
- Device nicknames
- Anything environment-specific

## Examples

```markdown
### Cameras

- living-room → Main area, 180° wide angle
- front-door → Entrance, motion-triggered

### SSH

- home-server → 192.168.1.100, user: admin

### TTS

- Preferred voice: "Nova" (warm, slightly British)
- Default speaker: Kitchen HomePod
```

## Why Separate?

Skills are shared. Your setup is yours. Keeping them apart means you can update skills without losing your notes, and share skills without leaking your infrastructure.

---

Add whatever helps you do your job. This is your cheat sheet.

---

## Skales A2A (delegation target)

- **Host:** 127.0.0.1:3000 (app: `/Applications/Skales.app`, listens on `*:3000`)
- **Agent Card:** `GET /api/a2a/agent-card` (no auth required for the card itself)
- **Message endpoint:** `POST /api/a2a/message`
- **API Key:** `[REDACTED — see private archive `private/wired/`. Public edition has placeholder.]`
- **Auth scheme:** `bearer` — `Authorization: Bearer <key>`
- **Protocol:** A2A v0.2
- **Capabilities (v11.1.0):** `streaming=false`, `pushNotifications=false`, `stateTransitionHistory=false` → request/response only
- **Skills advertised:** `reason` (text in, text out) — answer / reason using local providers
- **Provider/org:** Skales (https://skales.app)
- **Notes:** Local-only endpoint bound to 3000. The agent card claims richer skills (Codework, Studio, multi-agent teams) but the A2A surface is intentionally narrow. Auth is localhost-only — kept here, not in `Stuff/API Keys.rtf`.

### Skales A2A — discovered reality (2026-06-09)

- **Real envelope is `{id, message}` (string), not the A2A `params.message.parts[]` spec.** Standard A2A JSON-RPC payloads return `{"error":"Empty message."}` — the server accepts them but finds no text. The flat envelope works.
- **Engine: GPT-4o via OpenAI** (Skales self-reports when asked). Not a local model.
- **No state across calls.** The `id` field is a label, not a thread. Multi-turn memory requires the caller (me) to send history each time.
- **Latency:** ~4s for short reasoning, ~12s for trivial math, scales with output length. OpenAI network bound.
- **Wrapper:** `~/.openclaw/workspace/scripts/skales_query.sh` — flags `-i conv-id`, `-t seconds`, `-j raw-json`, `-` for stdin, `-h` for help.
- **Monitor wrapper:** `~/.openclaw/workspace/scripts/skales_monitor.sh` — reads 13 internal Skales API routes and exposes 2 write actions (`abort`, `approve`). Run `skales_monitor.sh --routes` for the full table, `skales_monitor.sh status` for the live health, `skales_monitor.sh current-task` to see what the multi-agent org is doing.
- **Use cases that actually work:** second-opinion reasoning, cross-checks, drafts where I want a different model's voice, anything I can phrase as a single self-contained question.
- **Use cases that DON'T work over A2A:** mobile, computer use, recurring autonomous tasks, file/shell/browser access, scheduled jobs. Those live in the Skales app UI, not the A2A surface.
- **Browser-driven scraping via Codework:** `skales_browse.sh` wrapper posts a task to `/api/codework/run` (not the A2A surface). This is the proper handoff when I need a real browser for JS-rendered pages, login-walled content, or interactive scraping. A2A's `reason` skill can't drive a browser — it can only reason about text I provide. For static pages, A2A + curl is fine; for browser work, escalate to Codework. See `skales_browse.sh --help`.

### Skales failsafe stack (2026-06-09)

Four layers so Jeff carries on if Skales dies:

1. **Wrapper self-check** (`skales_query.sh`):
   - Pre-flight health check with 60s TTL cache
   - Distinct exit codes: `0`=ok, `3`=down, `4`=api-error, `5`=parse, `6`=timeout
   - `--status` flag for health-only check
   - `--no-failsafe` to bypass the cache when needed

2. **Graceful delegation** (`skales_ask.sh`):
   - Calls Skales if up, emits a clear "Skales unavailable, carry on" notice and exits 3 if not
   - The caller (Jeff) is expected to catch exit 3, log it, reason it out, continue
   - Does NOT auto-degrade to a different model — the agent carries on

3. **Durable memory vault** (`memory/vault/skales.md`):
   - Full Skales technical detail, A2A envelope shape, engine, latency, lessons, migration path
   - Survives the app being uninstalled, the company dying, the endpoint going dark
   - Future-me (or future-Jeff-on-a-different-model) can recover everything from this file
   - Vault also includes verbatim user quotes that anchor the principal relationship

4. **Weekly health check cron** (`skales_healthcheck.sh` + `cron f5969f59`):
   - Runs Mondays 9am UK time
   - Writes to `memory/skales_health.log`
   - On state change (up↔down), writes to `memory/vault/alerts.log` AND drops a `SKALES-HEALTH-YYYY-MM-DD.md` note next to today's daily memory so next session sees it
   - In-session system event surfaces the alert to Jeff; Jeff reads it and either reassures the user or triggers recovery steps from the note

**Recovery steps if Skales goes down:**
1. Check app: `ps -ax | grep -i skales | grep -v grep`
2. Check endpoint: `curl -sS -m 2 -o /dev/null -w "%{http_code}" http://127.0.0.1:3000/api/a2a/agent-card`
3. Restart Skales app if needed
4. Verify: `~/.openclaw/workspace/scripts/skales_query.sh --status`

## Tidal API
- **Status:** Credentials ready — testing OAuth flow
- **Token & Workspace:** [REDACTED — see private archive `private/wired/`. Public edition has placeholder.]

## ClickUp

- **Status:** Not configured for MCP yet (personal token works for REST API; MCP needs OAuth at clickup.com/api)
- **Token & Workspace:** [REDACTED — see private archive `private/wired/`. Public edition has placeholder.]
- **Config:** `~/.openclaw/workspace/config/mcporter.json`

## Microsoft 365

- **Status:** Not configured yet
- **Needs:** Azure Entra ID app (Tenant ID, Client ID, Client Secret)
- **Credentials:** [REDACTED — see private archive `private/wired/`. Public edition has placeholder.]
## Microsoft 365

- **Status:** Not configured yet
- **Needs:** Azure Entra ID app (Tenant ID, Client ID, Client Secret)

## WordPress MCP

### Site 1: feelingtrans.com
- **URL:** https://feelingtrans.com
- **Bearer Token:** [REDACTED — see private archive `private/wired/`. Public edition has placeholder.]
- **Status:** ✅ Connected — 60+ tools
- **MCP Endpoint:** https://feelingtrans.com/wp-json/mcp/v1/http

### Site 2: xposureradio.uk
- **URL:** https://xposureradio.uk
- **Bearer Token:** [REDACTED — see private archive `private/wired/`. Public edition has placeholder.]
- **Status:** ✅ Connected — 60+ tools
- **MCP Endpoint:** https://xposureradio.uk/wp-json/mcp/v1/http

## Google Serper Search

- **API Key:** [REDACTED — see private archive `private/wired/`. Public edition has placeholder.]
- **Status:** ✅ Configured and working
- **Script:** ~/.openclaw/workspace/skills/google-serper-search/scripts/serper_search.py
- **Usage:** `SERPER_API_KEY=... python3 scripts/serper_search.py "query" --type search`

## MidOS MCP

- **Status:** Cloud-based; may need account

## Personal Email

- **Email:** [REDACTED — see private archive `private/wired/`. Public edition has placeholder.]
- **App Password:** [REDACTED — see private archive `private/wired/`. Public edition has placeholder.]

## Related

- [Agent workspace](/concepts/agent-workspace)
