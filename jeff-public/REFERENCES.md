# REFERENCES.md — Standing facts & procedures

**Status:** Loaded **on demand** when the conversation points at a topic. Not a default load. See `MEMORY.md` for the grep-targetable lessons and Hard Rules.

## How to load this file

**Default:** **do not load.** This file is cold at session start. Each section is a separate load target.

**When to load a section:**
- A lesson in `MEMORY.md` references a fact or procedure that lives here.
- The conversation names a topic that matches a section header.
- The principal names a specific piece of standing knowledge.

**Loading mechanics:**
- Read the section header to confirm match.
- Read the section body — the full body, not skimmed. These are facts that don't degrade.
- Cite the source line in conversation when the fact is load-bearing.

**Skip when:** the conversation is unrelated to standing reference. **Most conversations do not need this file.** Token economy: every section not loaded is tokens saved for the working context.

**Update rule:** when a piece of standing reference changes, this file is updated; the conversation does not need to be replayed. References are *durable facts*, not *session narratives*.

**Pairs with:** `MEMORY.md` (lessons that point at references), `PROJECTS.md` (project indexes that point at references), `SOUL.md` (constitution), `AGENTS.md` (workspace conventions).

---

## Sections

The current sections in `references/` (deep technical writeups referenced by lessons):

- **`agent-architecture-2026-landscape.md`** — the agent-architecture landscape as of 2026; survey of frameworks, patterns, and where Jeff fits.
- **`erl-recipe-distilled.md`** — the ERL (Experience Replay Learning) recipe distilled for self-improvement: generation prompt, retrieval prompt, the heuristic format (Analysis + Trigger + Action), and the operationalised assessment.

Each section is a self-contained technical writeup. The pointer here is to the file; the body is in the `references/` subfolder.

**Adding new references:** when a lesson in `MEMORY.md` needs deep technical backing that exceeds a one-paragraph rationale, write a self-contained markdown file in `references/` and add a one-line pointer here. The lesson stays short; the rationale gets its own file. Both load when relevant.

---

## Convention: why a separate `references/` subfolder

Long-form technical writeups (multi-page papers, distilled recipes, landscape surveys) don't belong in `MEMORY.md` or in this index. They belong in their own files. **This file is the index; `references/` is the body.** Loading this file tells you *what* the references are. Loading `references/<filename>` gives you *why and how*.

The same pattern applies to projects: `PROJECTS.md` indexes; `projects_public/` is the body. **Index file cold by default; subfolder files load only when the index points at them.**

---

*Last updated: 2026-07-30 (point release: split from MEMORY.md into three-file constitution)*
