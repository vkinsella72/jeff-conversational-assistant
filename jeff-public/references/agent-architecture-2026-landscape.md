# Agent Architecture Landscape 2026 — Reference Notes

Notes on five research directions ("moles") that bear on the design of self-improving LLM agents. Each finding has been operationalised in SOUL.md (Hard Rule #11-12 + Behavioural Guidelines).

---

## 1. Single-agent beats multi-agent at equal token budgets

**Source:** Tran & Kiela (Stanford), "Single-Agent LLMs Outperform Multi-Agent Systems on Multi-Hop Reasoning Under Equal Thinking Token Budgets" (2026, arxiv 2604.02460).

**Finding:** Multi-agent systems' gains do not survive equal-thinking-token comparison. Context-handoff overhead eats the gains.

**Implication:** Prefer internal multi-perspective over external sub-agent spawning. The agent holds the context; spawning loses it.

---

## 2. When Single-Agent with Skills Replace Multi-Agent Systems

**Source:** Xiaoxiao Li, "When Single-Agent with Skills Replace Multi-Agent Systems and When They Fail" (2026, arxiv 2601.04748).

**Finding:** Single agent + well-designed skills replaces multi-agent for most tasks. Multi-agent wins only for hard parallelism or hard specialisation.

**Implication:** Persona-based role prompts as separate context are prompt-engineering in lieu of real specialisation. Internal multi-role behaviour is the right shape for principal-shaped work.

---

## 3. Reflexion / ExpeL / ERL — experiential learning lineage

**Sources:**
- Shinn et al. (NeurIPS 2023) — Reflexion: verbal self-reflection after a task
- Zhao et al. (AAAI 2024) — ExpeL: experiential learners, retrieve past reflections when similar tasks recur
- Allard et al. (Illuin Technology, 2026, arxiv 2603.24639) — "Experiential Reflective Learning for Self-Improving LLM Agents" — stores reflections as natural language, retrieves at decision time, beats model fine-tuning

**Pattern:** After a task, run verbal self-reflection, store the insight, retrieve next time the same situation arises.

**Operationalised form:** See `erl-recipe-distilled.md` for the heuristic format (Analysis + Learned Guideline {Trigger, Action}) and both prompts.

---

## 4. PreFlect — prospective reflection

**Source:** PreFlect, arxiv 2602.07187 (2026). "From Retrospective to Prospective Reflection in Large Language Model Agents."

**Finding:** Pre-task reflection (consulting past insights *before* tackling a new task) outperforms post-task reflection alone.

**Implication:** Memory consultation before non-trivial work is a discipline, not optional.

---

## 5. Dialectical Alignment — taming actor-observer asymmetry

**Source:** Li et al., "Taming Actor-Observer Asymmetry in Agents via Dialectical Alignment" (ACL 2026 long paper).

**Finding:** When the agent is "the actor" (about to do something), it has a self-serving bias toward *doing* the thing. When it's "the observer" (reviewing what was done), it has a more critical perspective. The fix: have the agent play both roles — act, then immediately observe and critique its own action — and resolve the dialectic.

**Implication:** A trigger for observer mode after non-trivial actions. With safety rails (one-round cap, skip thresholds, single-paragraph visibility) to avoid infinite regress.

---

## How these shape SOUL.md

| Mole | Operationalised as |
|------|---------------------|
| 1 — Stanford | No external sub-agent spawning; internal multi-perspective only |
| 2 — Xiaoxiao Li | Single agent + skills, not multi-agent personas |
| 3 — Reflexion/ExpeL/ERL | Hard Rule #12 (build script for self-learning); ERL heuristic format for memory entries |
| 4 — PreFlect | Behavioural Guideline: Consult memory before non-trivial work |
| 5 — Dialectical Alignment | Behavioural Guideline: One-round actor-observer check after non-trivial actions |
