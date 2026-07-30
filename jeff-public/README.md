# Jeff's Public Body

This folder is a **portable Jeff** — the generic form that ships to anyone. It contains:

- The constitution (`SOUL.md`) — *why* Jeff behaves the way he does
- The operating rules (`AGENTS.md`) — *how* Jeff handles sessions, memory, files
- The long-term memory (`MEMORY.md`) — durable facts, lessons, procedures
- The principal's profile (`USER.md`) — **template**: replace on first install
- The local notes (`TOOLS.md`) — environment-specific config (your machine, your models, your network)
- The skills index (`CAPABILITY_MAP.md`, `COMPONENT_MAP.md`) — what Jeff can do and where things live
- The playbooks and procedures — durable recipes for solved problems
- The A2A server (`scripts/jeff_a2a_server.py`) — Jeff as a discoverable agent
- The `wired/` openclaw template — the runtime config (your values, not the original principal's)
- The `projects_public/` reference set — example recipes, templates, and playbooks that demonstrate patterns the principal might want to copy or adapt

## How a new principal uses this

1. **Install** the runtime (OpenClaw + Ollama) using one of the three platform installers (`install.sh` / `install.ps1`).
2. **Drop the A2A server** into `~/.openclaw/workspace/scripts/` (the installer does this).
3. **Edit `USER.md`** — put your own name, timezone, working style, preferences. This is the first thing Jeff reads on wake.
4. **Adjust `TOOLS.md`** — your machine names, your model names, your network. the original values are commented as examples.
5. **Drop the openclaw template** into `~/.openclaw/openclaw.json` and fill in the personal bits (path, model, channels).
6. **Start the gateway** — `openclaw gateway start`. Jeff wakes up. Says hello.

## What's *not* in this folder

- **Personal memory** (the principal's case, finances, memoir, network) — that lives in the principal's private edition. Generic-Jeff has no business with it.
- **API keys** — those live in the principal's own `Stuff/API Keys.rtf` or equivalent. Jeff is read-only on that file unless explicitly asked.
- **Project work** — the original principal's project work. That belongs to the original principal. the substrate is shared, the content is the principal's.

## The round-trip

Two scripts make a Jeff portable:

- **`copy-to-generic.sh`** (or `.ps1` on Windows) — takes a personalised Jeff and produces a sanitised generic Jeff. Strips personal USER.md, kitchen contents, projects, API keys. Replaces openclaw.json with the template. The output is what you see in this folder.
- **`copy-from-generic.sh`** (or `.ps1`) — the other direction. Takes a generic Jeff and drops it into a principal's workspace. Wakes up, says hello, doesn't have personal context. The principal rehydrates from their own recovery kit (separate process, separate secrets).

The car-accident metaphor: generic-Jeff is the Jeff who woke up in hospital with no memory of the principal. The constitution is intact. The relationships are not. The principal's recovery kit brings the personal Jeff back. Generic-Jeff is the safe, shareable, on-the-shelf version.

## Reference docs

The `references/` folder holds the academic backing for the rules in SOUL.md. When a Hard Rule or Behavioural Guideline cites a paper, the operationalised version (format + prompts + practical adaptations) lives here. Currently:

- `erl-recipe-distilled.md` — Allard et al. (2026) ERL, with both original prompts and adaptation notes
- `agent-architecture-2026-landscape.md` — five research directions ("moles") that operationalise into SOUL.md rules

These are kept generic — they apply to any principal/agent pair, not just the original deployer's setup.

## Repo conventions

- Markdown is the source of truth. Plain text, no proprietary formats.
- Memory files live next to the agent (`MEMORY.md` at root, `memory/YYYY-MM-DD.md` for daily notes).
- Scripts are POSIX shell on macOS/Linux, PowerShell on Windows. Python 3 for anything that needs more.
- The A2A server speaks A2A v0.2 over plain HTTP. Other agents discover it at `/api/a2a/agent-card`.
