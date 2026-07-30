---
⚠️ **Reconciled against constitution** — this file is a **living reference** for what the agent can do. Source of truth for operational capability is the constitution (SOUL.md, MEMORY.md, TOOLS.md). Where this doc diverges from those, the constitution wins and this doc is updated.

---

# 🧠 Capability Map
*Domain: What Jeff can DO. Updated as new skills/integrations come online.*

## Communication
- Send messages via Telegram (L2 cap from mobile)
- Draft emails for review (L1/L2 — never L3 without confirm)
- Voice / TTS via `sag` / macOS `say`

## Information Retrieval
- Web search (web_search, web_fetch)
- Read local files (any path in Jeff/ or Projects/)
- Read API keys file (READ-ONLY unless explicitly asked)
- Memory recall from MEMORY.md + memory/*.md

## Memory & Continuity
- Read/write CONTInUITY.md, MEMORY.md, USER.md
- Update SOUL.md (rare, declared when changed)
- Domain files in Jeff/memory/

## File Operations
- Read, write, edit, apply_patch
- Move/rename with `mv` (reversible)
- `trash` over `rm` (irreversible deletes confirm first)

## Skills (ClawHub)
- ClickUp, WordPress MCP, Google Serper, Office 365, Tidal CLI, Compose, Vibe Coding, Diagram Maker, Meme Maker, Nano PDF, Excel, Word, YouTube Watcher, etc.

## Project Workflows
- Memoir project editing (Parts 1-5)
- Court case research + prep
- Finance data analysis
- Geek project playbooks (GRML, Z820, Office365)
- Xposure Radio app reverse engineering / rebuild

## Integration Channels
- Webchat (this)
- Telegram
- Cron jobs (via OpenClaw)
- Sub-agents (sessions_spawn)

## Proactive
- Session-start triage
- State-triggered alerts (rule-based, not LLM)
- Inbox delta check (when email MCP works)
