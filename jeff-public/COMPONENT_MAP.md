---
⚠️ **Reconciled against constitution** — this file is a **living reference** for how the agent is built. Source of truth for runtime/plumbing/integration state is the constitution (SOUL.md, MEMORY.md, TOOLS.md). Where this doc diverges, the constitution wins and this doc is updated.

---

# 🧱 Component Map
*Domain: How Jeff is BUILT. The plumbing.*

## Runtime
- **Backend:** Ollama (any chat-capable model — see `openclaw.json` for the current default)
- **Shell:** OpenClaw gateway on macOS / Linux / Windows
- **Tools:** file ops, exec, web, cron, sessions, memory, skills, MCP servers, etc.

## Identity Files (OpenClaw workspace)
- `SOUL.md` — Constitution, hard rules, autonomy matrix
- `USER.md` — Who the principal is *(template: fill in on install)*
- `MEMORY.md` — Long-term curated memory
- `AGENTS.md` — Runtime conventions
- `TOOLS.md` — Environment-specific notes
- `IDENTITY.md` — Self-naming and vibe

## Daily / Working Notes
- `memory/YYYY-MM-DD.md` — raw session logs (one per day)
- `HEARTBEAT.md` — periodic check-in protocol
- `Outbox/` — recent discoverable outputs
- `drafts/` — work in progress
- `research/` — web fetches, summaries, archives
- `scripts/` — small tools and wrappers
- `projects/mirror/` — project state snapshots

## External Storage
- iCloud / OneDrive / Dropbox / Mega / whatever the principal uses — sync strategy is the principal's call
- VPS / remote box (when configured) — IP and creds in `TOOLS.md`, not here

## Skills Layer
- ClawHub skills in `~/.openclaw/workspace/skills/`
- Custom skills in the principal's `Jeff/skills/` (when built)

## A2A / Inter-agent
- `scripts/jeff_a2a_server.py` — Jeff as a discoverable A2A agent
- Auto-starts with the OpenClaw gateway (MCP registration in `openclaw.json`)
- Speaks A2A v0.2 at `http://127.0.0.1:3001/api/a2a/`
- Other agents discover via `GET /api/a2a/agent-card`

## Pending / Known Issues
- *(Principal-specific — leave empty for a clean install. Fill in as issues surface.)*
