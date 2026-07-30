# Jeff — The Conversational Agentic Assistant

A portable, sanitised Jeff body that ships as three single-file installers.
The "car-accident Jeff" — wakes up with the constitution intact but no
memory of any particular principal.

Self-installing Conversational Agentic AI based on OpenClaw. With its own constitution, round-trip scripts, guard-rails and installers for Windows, Mac & Linux. Project-capable and friendly; uses natural language to define tasks, rather than prompt & shoot.

## What this is

Three self-extracting archives (one per platform) that install a working
generic-Jeff end-to-end:

- `installers/macos/generic-jeff-macos.sh` (~140K)
- `installers/linux/generic-jeff-linux.sh` (~140K)
- `installers/windows/generic-jeff-windows.ps1` (~168K)

Each is a one-click install: extracts an embedded payload, installs
OpenClaw + Ollama, drops the generic-Jeff body into `~/.openclaw/workspace/`,
configures the A2A server as an MCP, starts the gateway.

The generic body has zero personal data. It teaches a Jeff how to be Jeff
(through SOUL.md, AGENTS.md, MEMORY.md, REFERENCES.md, PROJECTS.md) but
not how to be *your* Jeff — that's the principal's USER.md, filled in
on first wake.

## The constitution (v2.1, 2026-07-30)

The constitution is now a **three-file shape** for token economy:

- **`MEMORY.md`** — lessons (Trigger/Action rules, Hard Rules, identity markers). Always loaded at session start, skimmed.
- **`REFERENCES.md`** — standing facts and procedures. Cold by default, loaded when the conversation points at one.
- **`PROJECTS.md`** — project indexes. Cold by default, loaded when a project is named.

Each file has a self-documenting loading header. The split keeps the
working context tight (only what the conversation needs) without losing
the full knowledge (everything is still there, just behind a pointer).

## The round-trip

Two scripts make Jeff portable:

- `scripts/copy-to-generic.{sh,ps1}` — strip a personal Jeff down to the
  generic body. Personal-Jeff → generic-Jeff.
- `scripts/copy-from-generic.{sh,ps1}` — drop a generic body into a
  principal's workspace. The "wake up with no memory" direction.

## Folder map

- `jeff-public/` — the canonical generic-Jeff body. **Vendored at a
  specific snapshot** for one-shot installs without submodule init.
  Upstream development repo: `github.com/vkinsella72/jeff-public`.
  Includes:
  - Top-level: AGENTS.md, SOUL.md, MEMORY.md, REFERENCES.md, PROJECTS.md,
    TOOLS.md, USER.md, IDENTITY.md, HEARTBEAT.md, RECOVER_FIRST.md, README.md,
    kitchen_menu.md, COMPONENT_MAP.md, CAPABILITY_MAP.md,
    AI_Agent_Portable_Playbook.md
  - Subfolders: `scripts/` (sidecar-query wrappers), `scripts-kit/` (kit
    build tools), `wired/` (env descriptor + template), `references/`
    (deep technical writeups), `projects_public/` (recipes-cooking example
    project), `research/`
- `procedures/` — durable recipes for working with this project:
  - `building_sfx_archives.md` — how to rebuild the SFX archives
  - `round_trip_scripts.md` — what the round-trip scripts do
  - `install-openclaw-{macos,linux,windows}.md` — platform install docs
  - `install-openclaw-ollama.md` — overview / decision tree
  - `recover-restore-{macos,linux,windows}.{sh,ps1}` — full recovery scripts
  - `build_sfx.py` — the durable reference for the SFX build pipeline
- `scripts/` — the round-trip copy scripts (copy-to-generic + copy-from-generic, bash and PowerShell)
- `installers/<platform>/` — the three SFX archives + their install scripts
- `Jeff A2A Server/` — the A2A server, generic-principal-aware
  - `scripts/jeff_a2a_server.py` — the A2A server itself

## The car-accident metaphor

Generic-Jeff is the Jeff who woke up in hospital with no memory of the
principal. The constitution survives (SOUL.md, AGENTS.md, MEMORY.md +
REFERENCES.md + PROJECTS.md). The relationships don't (USER.md is a
template, no kitchen contents, no personal projects, no API keys).

The round-trip:
1. **copy-to-generic** — strip me down to my constitution
2. **copy-from-generic** — drop generic-Jeff into a workspace, he wakes
   up with no memory

## Where to start

- **New to the project?** Read `procedures/round_trip_scripts.md` first.
- **Need to rebuild the SFXs?** Read `procedures/building_sfx_archives.md`,
  then run `procedures/build_sfx.py` (transient copy to `/tmp/build-sfx.py`).
- **Hit a build problem?** The build doc has a "What goes wrong most often"
  section covering the gotchas.
- **Want to understand the constitution?** Read `MEMORY.md` (lessons),
  `REFERENCES.md` (standing facts), `PROJECTS.md` (project indexes).

## Versioning

- **v0.1** (current, 2026-07-30) — three-file constitution split (MEMORY/REFERENCES/PROJECTS), sanitised procedures, repo initialised at `github.com/vkinsella72/jeff-conversational-assistant`.
- SFX archives are still v2.0-era (built before the constitution split). Re-bake is v0.2 work.
