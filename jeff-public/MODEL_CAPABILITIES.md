# MODEL_CAPABILITIES.md — Model Routing Map

**Purpose:** Before starting any non-trivial task, consult this file to pick the right model. Switch via `session_status(model="ollama/<model>")` before running the task.

**Last updated:** 2026-07-30 22:47 BST
**Source:** `/Users/vikki/.openclaw/openclaw.json` → `models.providers.ollama.models`

---

## Active Stack (primary + fallbacks)

| Model | Context | Output | Reasoning | Vision | Role |
|---|---|---|---|---|---|
| **kimi-k3:cloud** | 524,288 | 131,072 | No | No | **Conversation (primary)** |
| **minimax-m3:cloud** | 524,288 | 131,072 | Yes | Yes | **Reasoning + Vision (fb 1)** |
| **deepseek-v4-pro:cloud** | 524,288 | 131,072 | Yes | No | **Reasoning-only (fb 2)** |
| **gemma4:31b-cloud** | 262,144 | 131,072 | Yes | Yes | **Budget reasoning+vision (fb 3)** |

---

## Model Selection Rules

### Conversation (default)
- **Model:** `ollama/kimi-k3:cloud`
- **When:** Chat, banter, quick answers, file reads, simple edits, recipe lookups, memory searches.
- **Why:** Fast, no reasoning overhead, 524k window. The daily driver.

### Reasoning (complex tasks)
- **Model:** `ollama/minimax-m3:cloud` (preferred) or `ollama/deepseek-v4-pro:cloud`
- **When:** Multi-step operations, code review, config surgery, batch file ops, anything where "confident but wrong" is expensive.
- **Why:** Reasoning mode catches errors before committing. MiniMax preferred because it also has vision; DeepSeek is reasoning-only.

### Vision (image analysis)
- **Model:** `ollama/minimax-m3:cloud` (preferred) or `ollama/gemma4:31b-cloud`
- **When:** Screenshots, OCR, photo analysis, diagram reading, browser snapshots.
- **Why:** MiniMax has 524k window + vision; Gemma4 has 262k window + vision (budget fallback).

### Budget / Emergency
- **Model:** `ollama/gemma4:31b-cloud`
- **When:** Primary + first two fallbacks all failed. Keep-the-lights-on mode.
- **Why:** Smallest window (262k), reasoning on, vision on. Survivable but not performant.

---

## Full Model Catalog (all available)

| Model | Context | Output | Reasoning | Vision |
|---|---|---|---|---|
| kimi-k3:cloud | 524,288 | 131,072 | No | No |
| minimax-m3:cloud | 524,288 | 131,072 | Yes | Yes |
| deepseek-v4-pro:cloud | 524,288 | 131,072 | Yes | No |
| gemma4:31b-cloud | 262,144 | 131,072 | Yes | Yes |
| kimi-k2.6:cloud | 262,144 | 262,144 | No | No |
| qwen3.5:cloud | 262,144 | 32,768 | No | No |
| nemotron-3-super:cloud | 262,144 | 65,536 | No | No |
| glm-5.1:cloud | 202,752 | 131,072 | No | No |
| minimax-m2.5:cloud | 202,752 | 8,192 | Yes | No |
| nemotron-3-ultra:cloud | 200,000 | 8,192 | No | No |

---

## Switch Discipline

1. **Checkpoint before switching.** Write current state to `memory/YYYY-MM-DD.md` before any model switch. If the switch kills context, the next model reads the checkpoint.
2. **Switch at natural phase breaks.** Don't switch mid-batch-write or mid-repo-push. Complete the work, commit to disk, then switch.
3. **Switch back to Kimi-K3 after every task.** The conversation model is the default. Specialist models are tools, not identities — consult them, don't become them. This keeps the voice consistent and makes the model-agnostic layer real.
4. **Primary stays Kimi-K3.** On-the-fly switches are session-scoped; the config primary doesn't change.

### How to switch (verified 2026-07-30)

- **To a specialist (fallback):** `session_status(model="ollama/<model>")` where `<model>` is in the fallbacks list. Examples: `minimax-m3`, `deepseek-v4-pro`, `gemma4`.
- **Back to conversation (primary):** `session_status(model="default")`. This resets to the config primary. You **cannot** switch directly to the primary model by name — it returns "not allowed."
- **Adding a new switchable model:** Add the model to `agents.defaults.model.fallbacks` in `openclaw.json`. The fallbacks list is the switchable pool.

### Config drift check (when switching primary)

When the primary model changes, **check every model reference in the config**, not just the obvious ones:
- `agents.defaults.model.primary` ✓
- `agents.defaults.model.fallbacks` ✓
- `agents.defaults.models` (allowlist) ✓
- `plugins.entries.memory-core.config.dreaming.model` ← **often missed**
- `plugins.entries.memory-core.subagent.allowedModels` ← **often missed**
- Any other plugin model references (wiki, voice, etc.)

*Lesson from 2026-07-30: switched to Kimi, forgot memory-core was still on MiniMax. Caught by Vikki 23:06 BST.*

These run on the local Ollama instance. They're the "internet is down" safety net. Capability is lower than cloud models; use only when cloud is unavailable.

| Model | Context | Size | Family | Notes |
|---|---|---|---|---|
| **nomic-embed-text:latest** | 2,048 | 274MB | nomic-bert | Embedding model only — not conversational. Used for memory search. |
| **databasemanaging/WormGPT:latest** | 131,072 | 2.0GB | llama (3.2B) | Small Llama variant. Survivable for basic chat. |
| **donovanbrady102/WormGPT2.0:latest** | 2,048 | 1.6GB | phi2 (3B) | Tiny Phi-2. 2k context is barely usable. Last resort. |
| **blackgrg26/WORMGPT-14:latest** | — | 37KB | — | Broken/missing. Do not use. |

**Local model routing:** If cloud is down, fall back to `databasemanaging/WormGPT:latest` (131k context, 3.2B params). It's not good, but it's better than nothing. The other two local models are too small to be useful for anything beyond embedding or emergency single-turn replies.

---

## Known Limitations

- **Gemma4 is a capability cliff.** Switching to Gemma4 (budget) from any of the top three is a significant downgrade. Avoid unless all three higher models have failed.
- **DeepSeek has no vision.** If a task needs both reasoning AND vision, MiniMax-m3 is the only option in the active stack.
- **Kimi-K3 has no reasoning.** For complex multi-step work, switch to MiniMax or DeepSeek before starting.
- **minimax-m2.5 is deprecated.** 202k context, 8k output. Not in the fallback chain. Don't use.
