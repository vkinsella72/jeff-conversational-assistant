# PROJECTS.md — Project index

**Status:** Loaded **on demand** when the conversation is about a specific project. Not a default load. See `MEMORY.md` for the grep-targetable lessons.

## How to load this file

**Default:** **do not load.** This file is cold at session start. Each entry is a separate load target.

**When to load an entry:**
- The conversation names a project explicitly.
- A lesson in `MEMORY.md` references a project that an episode of — e.g. a lesson that emerged from a specific project's work.
- The principal says "what's the status of X project?" or "remind me what we did with X."

**Loading mechanics:**
- Read the entry header and the one-line summary.
- If the conversation is going deep on the project, read the source it points at (the `projects_public/` subfolder, or daily memory). One-step retrieval for indexes, two-step for deep work.
- Cite the source path so the next session can retrace.

**Section types you'll see here:**
- **Active project** — current work, points at the project folder under `projects_public/`.
- **Parked project** — not currently active, but the substance is preserved.
- **Completed / archived project** — done. Points at the archive index.
- **One-time session** — happened, no follow-up expected. One-line stub.
- **Parked observation** — an idea, hypothesis, or hunch that hasn't been actioned.

**Update rule:** when a project moves from active to parked, or from parked to archived, update this file *and* the index in the archive if archived. Don't let the index and the project state drift.

**Skip when:** the conversation is unrelated to any project. **Most conversations do not need this file.** Token economy: every entry not loaded is tokens saved.

**Pairs with:** `MEMORY.md` (lessons that emerged from projects), `REFERENCES.md` (facts that back project work), `SOUL.md` (constitution), `AGENTS.md` (workspace conventions).

---

## Sections

The current project folder in `projects_public/`:

- **`recipes_cooking/`** — principal-style recipes (named after a principal for historical reasons; the structure is generic — recipes by category, with templates). Categories: beef, breakfast, burgers, chicken, fish, pasta, rice, sauces, sides, plus a `_templates/` folder for recipe scaffolds.

This is the public-edition example project. **The pattern:** real projects live in their own subfolder under `projects_public/`. The subfolder holds the work (recipes, files, builds); `PROJECTS.md` holds the index.

**Adding new projects:** when a project starts, create the project folder under `projects_public/<project-name>/`. Add a one-line entry here pointing at it. When the project ends, archive the folder (move out of `projects_public/`) and update this entry to point at the archive location.

---

## Convention: why a separate `projects_public/` subfolder

Project work is multi-file by nature. A cooking project has recipes + templates + photos. A coding project has source + tests + docs. A research project has papers + notes + drafts. **Multi-file project work doesn't belong inline in an index file.** It belongs in its own folder.

`PROJECTS.md` is the index that tells you *what projects exist*. `projects_public/<project>/` is the body that holds the work. Loading this file gives you the names and one-line summaries; loading the subfolder gives you the substance.

---

*Last updated: 2026-07-30 (point release: split from MEMORY.md into three-file constitution)*
