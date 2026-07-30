---
⚠️ **Reconciled against constitution** — this file is a **reference**, not a rule source. The constitution (SOUL.md, MEMORY.md, TOOLS.md, USER.md, AGENTS.md, IDENTITY.md) is the gold standard. Where this document's recommendations conflict with the current constitution, **the constitution wins**, and this document is updated to reflect the current state.

Some of the patterns below are already implemented in the generic-Jeff constitution out of the box. The principal's first-job review is to check which ones; the rest will need configuration or extension. The constitution is the canonical reference — this playbook is the *menu* of options, not the *contract*.

---

# 🤖 AI Agent Portable Playbook — Distilled from Shubh Jain's 100 Tips

**Source:** Reddit r/ClaudeAI — "100 Tips & Tricks for Building Your Own Personal AI Agent" by Shubh Jain (May 2026)
**Scope:** This is a *distilled, portable, model-agnostic* version of the article. The raw piece is heavy on Claude Projects / Claude Code specifics; this version strips that and keeps what works on **any** backend (Kimi, GLM, Deepseek, Ollama, anything).

---

## 🎯 What this playbook is for

A personal AI agent should be:
- **Capable, not just generating content**
- **Model-agnostic** — the agent is the same agent regardless of the model underneath
- **Self-improving across sessions** — without bloat, drift, or "personality fade"
- **Proactive but not annoying** — surface what matters, stay quiet on the rest

This playbook is the **constitution + how-to** for getting there. The 100 tips below are sorted into portable buckets: "Adopt Now", "Adopt When You Hit The Wall", and "Defer (model-specific)".

---

## ✅ ADOPT NOW — Core portable principles (works on any backend)

These are the high-value, model-portable patterns. Most wire straight into the generic-Jeff substrate.

### A. Identity & Constitution (Tips 1–8)

| # | Pattern | What it means |
|---|---------|---------------|
| 1 | **Constitution, not system prompt** | SOUL.md should explain *why* the rules exist, not just list them. When the agent hits an edge case, it reasons from the *spirit* not the letter. |
| 2 | **Name, voice, role** | Pick a stable name + vibe in `IDENTITY.md`. The voice is portable; the accent is the principal's call. |
| 3 | **Hard rules vs behavioural guidelines** | Split the constitution into "NEVER" (hard) and "Default to" (soft). The split matters for autonomy decisions. |
| 4 | **Deep principal definition** | `USER.md` holds the principal's profile. Keep updating it as the relationship develops. |
| 5 | **Capability Map + Component Map (separately)** | One says *what* the agent can do; the other says *how* it's built. Different docs, different purposes. |
| 6 | **Define what the agent is NOT** | Add an "I am NOT" section. Not a search engine. Not a yes-machine. Not a summariser. The negations shape the positives. |
| 7 | **THINK vs DO mental model** | Uncertain → prepare + present, don't freeze. Clear → execute, don't ask twice. |
| 8 | **Version identity in git** | The OpenClaw workspace *is* git-trackable. `git init`, commit SOUL/USER/MEMORY, track changes. |

### B. Memory Architecture (Tips 9–18)

| # | Pattern | Portable? | Notes |
|---|---------|-----------|-------|
| 9 | Flat markdown over vector DBs | ✅ | Always. |
| 10 | Domain-separated files | ✅ | Split `memory/` into `entities_people.md`, `entities_projects.md`, `hypotheses.md`, `task_queue.md`, `waiting_on_user.md`, `ideas_log.md`, `development_backlog.md`. |
| 11 | MEMORY.md index | ✅ | `MEMORY.md` lists sub-files with one-liners. The index IS the memory surface. |
| 12 | Cache vs SSOT distinction | ✅ | Add `last_sync:` headers to anything cached from external systems. |
| 13 | session_hot_context.md with TTL | ✅ | Auto-expire entries >72h. |
| 14 | daily_note.md as brain-dump buffer | ✅ | The principal voice-dumps; the agent processes at session end. |
| 15 | hypotheses.md with confidence + aging | ✅ | 30-day expiry. |
| 16 | WAITING_ON_ME queue | ✅ | 7d nudge, 30d auto-close. |
| 17 | user_behavioural_profile.md | ⚠️ Partial | `USER.md` does some of this. Refine as the relationship develops. |
| 18 | Mirror memory to cloud | ✅ | iCloud / OneDrive / Mega / Git — whatever the principal uses. |

### C. Knowledge Library (Tips 19–23)

| # | Pattern | Portable? | Notes |
|---|---------|-----------|-------|
| 19 | Clustered library + INDEX.md | ✅ | Reference docs in `Stuff/`. `Stuff/INDEX.md` lists every entry. |
| 20 | Lazy-generated .brief.md per source | ✅ | First time the agent touches a doc, generate a one-pager. |
| 21 | 3-question Quality Gate | ✅ | Only cite if it adds framework, not just confirms. |
| 22 | Silent consultation | ✅ | A lot of the best agent work is invisible — checking context without narrating. Codify. |
| 23 | Pre-wire knowledge stacks per project | ✅ | When a project starts, tag 2-3 sources that apply. |

### D. Skills Architecture (Tips 24–31)

| # | Pattern | Portable? | Notes |
|---|---------|-----------|-------|
| 24 | Standalone skill folder + SKILL.md | ✅ | The ClawHub / skills pattern. |
| 25 | Explicit trigger phrases | ✅ | "Trigger:" line in every skill frontmatter. |
| 26 | "NOT FOR" sections | ✅ | Tell the agent when *not* to use the skill. |
| 27 | Skills vs agents distinction | ✅ | Skills = procedural. Agents = judgement. The agent uses skills; the agent *is* an agent. |
| 28 | Skills registry with usage tracking | ⚠️ Partial | Track installed + last-used + purpose. |
| 29 | /iterate skill | ✅ | PRODUCE → CRITIQUE → REFINE on every draft. |
| 30 | Output intensity levels | ✅ | MINIMAL / STANDARD / FULL modes. |
| 31 | Visible Outbox | ✅ | `Outbox/` — every output file gets a stub copy for discoverability. |

### E. Multi-Agent & Council (Tips 32–41)

| # | Pattern | Portable? | Notes |
|---|---------|-----------|-------|
| 32–35 | Dispatch matrix, parallel agents, briefing, forced verdicts | ✅ via `sessions_spawn` | Sub-agents already exist. Build a dispatch matrix. |
| 36–38 | 3-round Council, anchor voters, devil's advocate | ✅ | Apply to big decisions. Parallel positions → cross-examination → vote with dissent. |
| 39 | When to Council vs single | ✅ | Council = expensive. Default to single. Council trigger: 2+ valid paths AND genuine uncertainty AND meaningful irreversibility. |
| 40–41 | Structured handoffs + catch-all | ✅ | Sub-agents hand off with state. Normalise the format. |

### F. Session Management (Tips 42–47)

| # | Pattern | Portable? | Notes |
|---|---------|-----------|-------|
| 42 | Symmetric start/end | ✅ | Start: read continuity. End: write session log + close open loops. |
| 43 | Tiered closure (Light/Medium/Full) | ✅ | Light = save session log. Medium = + memory sync. Full = + autolearn. |
| 44 | Session-start hook (time, machine, etc.) | ✅ | Confirm it's firing — environment, time, model, key state. |
| 45 | Inbox delta + red alerts at start | ⚠️ | Inbox access is unstable. Add a manual cache when needed. |
| 46 | Scheduled task health at start | ✅ | Cron jobs checked at session start. |
| 47 | Correction count → spec rule | ✅ | 3x on the same thing → promote to constitution. |

### G. Decision Authority (Tips 48–54)

| # | Pattern | Portable? | Notes |
|---|---------|-----------|-------|
| 48 | Autonomy level matrix (L0–L4) | ✅ | L0: read. L1: write local. L2: create tasks/drafts. L3: send external (confirm). L4: financial (confirm). |
| 49 | Default to "THINK, don't ask" | ✅ | Already standard. Codify. |
| 50 | Reversibility tiers | ✅ | Reversible = silent. Irreversible = confirm. |
| 51 | Earned autonomy | ✅ | 10x success → propose expanding the level. |
| 52 | Principal hierarchy | ✅ | Root config > skill spec > session context. |
| 53 | Pre-send gate for high-stakes comms | ✅ | Never send external messages without asking. |
| 54 | Unconditional forcing functions | ✅ | Financial, HR, irreversible = always confirm. Hard-coded. |

### H. Proactive Initiative (Tips 55–60)

| # | Pattern | Portable? | Notes |
|---|---------|-----------|-------|
| 55 | Typed observations (BIZ/OPS/DEV/PAT) | ✅ | Classify everything the agent surfaces. |
| 56 | Anti-spam rules | ✅ | Quality over quantity. Use judgment, not arbitrary caps. |
| 57 | /spark mode | ✅ | "Go full spark" → disable anti-spam. |
| 58 | ideas_log.md | ✅ | Parked observations go here, not into the chat. |
| 59 | State-triggered alerts (rule-based) | ✅ | Build a `rules/alerts.md` with the actual rules. |
| 60 | development_backlog.md | ✅ | The agent self-reports gaps. |

### I. VIP / Contact Management (Tips 61–65)

| # | Pattern | Portable? | Notes |
|---|---------|-----------|-------|
| 61 | Tiered contact registry | ✅ | T1 (close), T2 (active), T3 (background). |
| 62 | Pre-communication profile load | ✅ | Before drafting any T1 message → check profile. |
| 63 | Silence tracking per T1 | ✅ | 14d with active biz = alert. |
| 64 | Knowledge stacks per relationship | ✅ | When active T1 work exists → pre-wire 2-3 sources. |
| 65 | Proactive T1 triggers at session start | ✅ | Bake into the session-start check. |

### J. Output & Communication (Tips 66–73)

| # | Pattern | Portable? | Notes |
|---|---------|-----------|-------|
| 66 | Pre-tool brevity (1 sentence) | ✅ | State what you're doing, do it. |
| 67 | Next N Steps with anti-bias (≥2 "don't"/"wait") | ✅ | Recommendations include the anti-options. |
| 68 | "Single best action" format | ✅ | For technical/audit prompts with stakes. |
| 69 | Three distinct colour grammars | N/A | Text-only. Skip. |
| 70 | No trailing summaries | ✅ | Cut "In summary" from outputs. Substance first; the work is the close. |
| 71 | Commit to a recommendation | ✅ | One recommendation, scored alternatives, why. |
| 72 | Clickable file references | ✅ | Output `file://...` links or clear file references. |
| 73 | Minimal mode ("quick", "briefly", "just the answer") | ✅ | Wire as explicit trigger phrase. |

### K. Files, Data & Integrations (Tips 74–85)

| # | Pattern | Portable? | Notes |
|---|---------|-----------|-------|
| 74 | No root files | ✅ | Always use a subfolder. |
| 75 | Routing table per file type | ✅ | Build `Jeff/file_routing.md`. |
| 76 | Deprecated path mapping | ✅ | When renaming a folder, log the old → new mapping. |
| 77 | Degraded mode for every integration | ✅ | When CRM/email/MCP dies, fall back to a local cache. |
| 78 | Announce data freshness | ✅ | Every output using external data → include age. |
| 79 | Raw data access | ✅ | Index the principal's CSVs, key docs, anything reference. |
| 80 | Item-belonging decision tree | ✅ | Where does a new item go? Build the tree, follow it. |
| 81–84 | Mobile channel | ⚠️ Future | When the principal wants Telegram / WhatsApp as agent source. |
| 85 | Fast/slow path per data source | ✅ | Build into the integration code. |

### L. Automation & Quality (Tips 86–93)

| # | Pattern | Portable? | Notes |
|---|---------|-----------|-------|
| 86 | Hooks, not memory, for must-run behaviours | ⚠️ | Use cron + lifecycle hooks for must-run. |
| 87 | Allowlist for safe read operations | ⚠️ | Most agents have full read; an allowlist is overkill. |
| 88 | AUTOLEARN end-of-day | ✅ | Session-end protocol: extract structured learnings. |
| 89 | Scheduled proactive tasks | ✅ | Cron for daily/weekly checks. |
| 90 | Error escalation ladders | ✅ | Same error 3x → surface + propose fix. |
| 91 | Regression test suite | ✅ | For identity changes, run a checklist. |
| 92 | Quarterly system audit | ✅ | Schedule it. |
| 93 | Different-model audit | ✅ | When the principal picks a model, audit with a different one monthly. |

### M. Meta & Mindset (Tips 94–100)

| # | Pattern | Notes |
|---|---------|-------|
| 94 | Constitution before skills | The foundation comes first. |
| 95 | Corrections = spec debt | Wire into behaviour. |
| 96 | 3 AM test | Would the principal be comfortable with this at 3am? If no → confirm. |
| 97 | Fail-open for context loading | When in doubt, load the file. Cheap. |
| 98 | Teaching capsules for new domains | First time touching a new domain → one-pager. |
| 99 | Cloud → local migration | The principle: real work needs real file access. |
| 100 | Agent mirrors your thinking | The model amplifies the spec; the spec is the driver. |

---

## 🟡 ADOPT WHEN YOU HIT THE WALL (advanced, situational)

Consider these only when pain signals them:

- **Council of 3 rounds** (36–37) — when one-off decisions are causing rework
- **Hypotheses.md with confidence** (15) — when second-guessing old calls
- **State-triggered alerts** (59) — when something slips through twice
- **Degraded mode per integration** (77) — when an integration fails mid-task
- **Different-model audit** (93) — when behaviour starts drifting

---

## 🔴 DEFER (model-specific, not portable)

Skip these — they're tied to specific vendor stacks:

- Claude Projects / Claude Code migration paths
- Vendor-specific `localhost:NNNN/open?path=X` URL conventions
- Tiered `vendor-model-Nx-max` references

---

## 📊 The 30,000-Foot View

| Bucket | % of 100 tips | Portable? | Adopt priority |
|--------|--------------|-----------|----------------|
| Identity & Constitution | 8% | ✅ | NOW |
| Memory | 10% | ✅ | NOW |
| Knowledge Library | 5% | ✅ | NOW |
| Skills | 8% | ✅ | NOW |
| Multi-agent | 10% | ✅ partial | LATER |
| Session Management | 6% | ✅ | NOW |
| Decision Authority | 7% | ✅ | NOW |
| Proactive | 6% | ✅ | NOW |
| Contact Management | 5% | ✅ | LATER (when T1 work increases) |
| Output & Communication | 8% | ✅ | NOW |
| Files & Data | 12% | ✅ | NOW |
| Automation & Quality | 8% | ✅ partial | LATER |
| Meta & Mindset | 7% | ✅ | NOW |

**Conclusion:** ~70% of the 100 tips are immediately adoptable on any model. The remaining 30% is situational or vendor-specific. **The unlock isn't a different model — it's a portable Constitution and a memory architecture that survives the model swap.**

---

*Distilled from Shubh Jain's 100 Tips (May 2026). The patterns travel; the principal picks the accent.*
