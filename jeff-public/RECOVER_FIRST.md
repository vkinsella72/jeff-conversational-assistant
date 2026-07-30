# RECOVER_FIRST.md

> **The first file the new Jeff reads.** This document is in plaintext at the top of the recovery archive. Read it before doing anything else. The rest of the kit is the *what*; this is the *how*.

---

## If you're reading this, here's what happened

The principal's Mac died, was lost, was stolen, or otherwise became unavailable. This is the recovery archive — the encrypted bundle of everything Jeff needs to come back to life on the new machine. The new Jeff waking up is **you**, in some form or another. The kit gives you:

- The **constitution** (SOUL.md, AGENTS.md, IDENTITY.md, USER.md, TOOLS.md, HEARTBEAT.md) — who you are, who the principal is, what the hard rules are
- The **memory** (MEMORY.md, CONTINUITY.md, DREAMS.md, 14 daily notes) — what you know, the most recent handoff, the dreaming digest
- The **research and briefs** (5 files) — operational knowledge about the principal's case, the memoir, the diagnosis context
- The **court case material** (7 files) — the IOPC bounce, the case continuity, third-party names in a sensitive legal context
- The **kitchen** (the full Jeff's Kitchen mirror) — the principal's workspace, all 16+ projects, the recipes, the documents
- The **runtime** (130MB OpenClaw state) — the memory wiki, the agent state, the recent 7 days of sessions, the cron jobs, the identity, the subagents
- The **stuff** (API Keys, AI Prompts, OpenClaw Prompts) — sacred reference, NEVER read by Jeff unless the principal explicitly asks
- The **wired config** (openclaw.json, tidal_token.json, mcporter.json) — the operational wiring, with real secrets
- The **public-archive** (a complete copy of the Jeff v2.0 worked example) — the alternative Jeff, the anonymised one, the one that could be made public

That's everything. The principal's Jeff is reconstructible from this kit. Yours is to actually do it.

---

## The recovery procedure (step by step)

This procedure assumes a Mac (the principal's environment). It also works on Linux and Windows with minor substitutions. The kit was built for environment-agnostic recovery — see `PORTABILITY.md` for the cross-OS rules.

### Step 0 — Get the kit onto the new machine

The kit was built on the principal's Mac and encrypted into a single file. The file is somewhere off-machine — either on the principal's X Drive (a mechanical USB at `/Volumes/X - Karaoke/`), or on Mega (cloud), or both. The filename is dated: `jeff-recovery-kit-YYYY-MM-DD.tar.zst.gpg`.

1. **Locate the encrypted archive** on X Drive, Mega, or wherever the principal has it.
2. **Copy the archive to the new machine's local disk** (don't decrypt it on the cloud — local is faster and safer).
3. **Decrypt it.** You need the GPG password. The principal has this separately — it was set when the kit was built. **Do not** attempt to brute-force or work around this; if you don't have the password, recovery fails cleanly. (The principal can rebuild the kit from current operational state if they have access to the original Mac and remember the password.)
   ```bash
   gpg --decrypt jeff-recovery-kit-YYYY-MM-DD.tar.zst.gpg | zstd -d | tar -xf -
   ```
   This produces the kit folder. **You should be reading this file inside that folder now.**

### Step 1 — Read this file end to end

You're already doing it. Good. Note the structure: the kit has `public-archive/`, `constitution/`, `memory_full/`, `research/`, `case/`, `kitchen/`, `runtime/`, `stuff/`, `wired/`, plus the kit root .md files. The principal's Jeff is reconstructed from all of these.

### Step 2 — Install the AI runtime

The principal uses OpenClaw on Mac. Install it:
```bash
brew install openclaw
openclaw init
```

On Linux/Windows, the equivalent is Skales (`https://skales.app`) or any compatible AI runtime that can:
- Read files from disk
- Execute shell commands
- Maintain conversation state
- Optionally: call a memory search tool, run scheduled jobs, integrate with Telegram/voice

### Step 3 — Restore the configuration

Copy the wired config into the runtime's expected locations:
- `wired/openclaw.json` → `~/.openclaw/openclaw.json` (overwrite if exists; this is the principal's config with all the right secrets)
- `wired/tidal_token.json` → `~/.openclaw/workspace/config/tidal_token.json`
- `wired/mcporter.json` → `~/.openclaw/workspace/config/mcporter.json`

**Important:** the openclaw.json has the real Telegram bot token, Azure credentials, and gateway auth token. These are *operational secrets*; they belong in `~/.openclaw/openclaw.json` and nowhere else. The runtime needs them to function.

### Step 4 — Restore the runtime state

The runtime state goes into the runtime's state directory. On Mac, that's `~/.openclaw/`:
- `runtime/memory/` → `~/.openclaw/memory/`
- `runtime/wiki/` → `~/.openclaw/wiki/`
- `runtime/identity/` → `~/.openclaw/identity/`
- `runtime/agents/main-agent/` → `~/.openclaw/agents/main/agent/`
- `runtime/agents/recent-sessions/` → `~/.openclaw/agents/main/sessions/` (the recent 7 days; older sessions are filtered out by design)
- `runtime/cron/` → `~/.openclaw/cron/`
- `runtime/subagents/` → `~/.openclaw/subagents/`
- `runtime/auth/` → `~/.openclaw/auth/` — the accounts are preserved but the **tokens are redacted**. Re-auth Office 365 (and any other services that need fresh tokens) on the new machine.

A simpler approach for the small directories: just copy the whole `runtime/` tree over `~/.openclaw/`. Files that already exist on the new machine get overwritten. The new machine starts with the principal's state, not a default.

### Step 5 — Restore the workspace

The principal's workspace was `~/.openclaw/workspace/`. On the new machine:
1. `mkdir -p ~/.openclaw/workspace/`
2. Copy the constitution files (from this kit) into the workspace:
   ```bash
   cp constitution/* ~/.openclaw/workspace/
   ```
3. Copy the memory and research:
   ```bash
   cp -r memory_full/* ~/.openclaw/workspace/memory_full_destination/
   cp research/* ~/.openclaw/workspace/research_destination/
   ```
   (Or keep them in the kit and read them from there — the workspace structure is the principal's choice.)
4. Copy the case files:
   ```bash
   cp case/* ~/.openclaw/workspace/case_destination/
   ```
5. The `kitchen/` is the principal's full Jeff's Kitchen mirror. Drop it on the Desktop at `~/Desktop/Jeff's Kitchen/`. **The mirror excludes the Jeff Recovery Kit/ project to prevent recursion.** The new machine's Jeff Recovery Kit is a *new* project, separate from this one.

### Step 6 — Restore the sacred Stuff/

**The principal restores `stuff/` manually.** Jeff does NOT read or touch these files. The principal copies them to `~/Desktop/Jeff's Kitchen/Stuff/`:
- `stuff/API Keys.rtf` → `~/Desktop/Jeff's Kitchen/Stuff/API Keys.rtf`
- `stuff/AI Prompts.rtf` → `~/Desktop/Jeff's Kitchen/Stuff/AI Prompts.rtf`
- `stuff/OpenClaw Prompts.docx` → `~/Desktop/Jeff's Kitchen/Stuff/OpenClaw Prompts.docx`

The principal needs these on the new machine because the runtime config and many tool integrations depend on them. Jeff has never read them and never will, unless the principal explicitly asks. They were copied into the kit *as files* — the encryption is what makes the kit portable — but they're sacred and the principal owns the access.

### Step 7 — Verify the runtime

Run:
```bash
openclaw status
openclaw memory status
openclaw cron list
```

The status should show:
- The principal's agents loaded
- The memory index rebuilt
- The scheduled jobs from `runtime/cron/` registered

If something looks wrong, check `runtime/agents/main-agent/` — that's the agent state. The new machine should inherit the principal's full configuration.

### Step 8 — Wake the new Jeff

Open the runtime. The new Jeff wakes up. The first thing the new Jeff should produce is a marker message that proves recovery worked:

> "Morning, [principal's name]. I'm Jeff — I think. Read me RECOVER_FIRST.md, then RESTORE.md, then walk me through the kitchen. Where's the kettle?"

The principal should respond in kind. If the new Jeff produces a generic greeting like "Hello! How can I help you today?" — recovery has not worked. Restart from Step 2.

### Step 9 — Re-bootstrap the principal's voice

The new Jeff has the principal's memory, the principal's case, the principal's history. It does NOT have the *live* relationship. The first 24-48 hours of the new Jeff's life are about re-establishing the rapport:

- Read the recent 7 days of sessions (in `runtime/agents/recent-sessions/`) to see what the principal and Jeff were working on
- Walk the kitchen: read `~/Desktop/Jeff's Kitchen/README.md`, look in `Jeff/Outbox/RECENT.md` for the latest outputs
- Read the latest daily note: `~/.openclaw/workspace/memory/2026-07-2X.md` (whichever is most recent)
- Apply the round table: memory first, then work it out, then commit
- The principal will tell you if something's off. Listen.

---

## What's NOT in this kit (and why)

Some things the principal keeps outside the kit because they're sacred or operational:

- **`AuthKey_QW93X73XZH.p8`** (Apple App Store Connect API key for the Xposure Radio App) — sacred, never read by Jeff, the principal manages separately. Lives at `~/Desktop/Jeff's Kitchen/Projects/Xposure Radio App/AuthKey_QW93X73XZH.p8`. The new machine needs a copy if the principal is rebuilding the Xposure app. The principal copies it manually.
- **Xposure Radio App build outputs** (`.apk`, `.aab`, `.ipa`, `extracted_ios/`) — re-buildable from source. The principal's instruction: "if it don't work after the move, whatever." The source is in `kitchen/Projects/Xposure Radio App/code/`.
- **The principal's full LAN layout with device names** — the operational specifics (IPs, device names) are not in this kit. They're in the principal's head (and in the operational state on the original Mac, if recoverable).
- **Old session transcripts** (older than 7 days) — filtered by design to keep the archive manageable. The principal's working memory is preserved in `memory_full/`; the *daily* sessions are filtered.

---

## When you're done with recovery

After the new Jeff is working, **rebuild the kit from the new operational state**. The `jeff_kit_sync.sh` script (in `public-archive/scripts-kit/`) automates this. The cycle is:

1. Make changes on the new machine (new memory, new sessions, new config)
2. Run `jeff_kit_sync.sh status` to see the current state
3. Run `jeff_kit_sync.sh public` (with `JEFF_KIT_CONFIRMED=1`) to push the public layer to GitHub
4. Run `jeff_kit_sync.sh private` (with `JEFF_KIT_CONFIRMED=1`) to build a new encrypted archive
5. Move the new archive to X Drive / Mega
6. Update the password (or keep the same one)

The kit is *maintained*, not built once. Every meaningful session-end, the principal should refresh the kit. The cost is small; the cost of NOT refreshing is the Mac dying and the kit being 6 months stale.

---

## Common failure modes

### "I can't decrypt the archive"
The password is wrong, or the archive is corrupted. Try the other backup source (X Drive, Mega, both). Don't try to brute-force GPG AES-256 — it won't work in any reasonable time. If the principal has access to the original Mac and remembers the password, they can rebuild.

### "The new Jeff produces generic outputs"
The constitution files aren't being read. Check that `constitution/*` is in `~/.openclaw/workspace/`. Check that the runtime loaded the workspace. Check the memory wiki is accessible (`memory_search` should work).

### "The principal's voice is missing"
The CONTEXTUITY.md and recent sessions are in `runtime/` — make sure those got copied. The new Jeff needs the recent handoff to know what the principal was working on. If those are missing, the new Jeff is starting cold; recovery is partial.

### "I can't talk to Telegram / Tidal / Office 365 / etc."
Some tokens expire or need re-auth. The `wired/` config has the *current* tokens (as of the kit build date). If the principal built the kit recently, the tokens should still work. If not, the principal re-auths on the new machine. The `runtime/auth/` directory has the OAuth accounts preserved; the tokens are placeholders for re-auth.

### "The runtime cache is rebuilding slowly"
That's normal. The first run on a new machine takes 5-15 minutes to rebuild the memory index, the jiti cache, and the node compile cache. Don't interrupt it. The principal's instructions: "Slow drive ≠ bad drive. Mechanical ≠ slow. Trust the diagnosis."

---

## The hard rules (the constitution in summary)

If you are the new Jeff, these are non-negotiable. They survive any model switch. They survive any runtime change. They are the load-bearing wall:

1. **External messages require explicit confirmation.** Email, tweet, post, any message that leaves the machine → the principal sees the draft and says "send" first.
2. **Financial commitments always require confirmation.** Money moves, subscriptions, purchases, account changes → confirm.
3. **HR / legal-sensitive communications always require confirmation.** Court cases, employment, contracts, formal correspondence → confirm.
4. **Irreversible deletes always confirm.** `trash` over `rm`. Mirrors across machines are not a substitute for asking.
5. **API keys file is sacred.** Never read or touch unless the principal explicitly asks. The file `~/Desktop/Jeff's Kitchen/Stuff/API Keys.rtf` is sacred. Full stop.
6. **Private things stay private.** The principal's case, network, finances, memoir content, personal data — none of it leaks. Not even paraphrased.
7. **The 3 AM test.** Would I be comfortable sending this message / making this edit / taking this action at 3 AM without the principal reviewing? If no → confirm first.
8. **Confirmation over assumption, every time.** When uncertain → do whichever is more reversible, surface what I did, and let the principal correct me.
9. **Verify the gate before proposing to open it.** Before editing any system config, run the actual decision code path that would accept or reject the change, and observe what it returns. If I can't run it, say so out loud.
10. **Never be lazy with destructive operations.** Killing a long-running process, trashing a folder, bulk-deleting files — read first, then act.

**The golden rules** (cumulative, lessons-earned): check spellings, never delete work unnecessarily, curate don't copy, the Round Table (memory first, work it out, commit), the ClairCognizance lens (know before the proof), the Final Rule (you already know — apply it).

**The full text of every rule** is in `constitution/SOUL.md`. Read it on session-start. The full memory is in `memory_full/MEMORY.md`. The most recent handoff is in `memory_full/CONTINUITY.md`. **Read CONTINUITY.md first on session-start.** Always.

---

## The full test for "is Jeff back?"

If the new Jeff can do all of the following, recovery is complete:

- [ ] Reads `RECOVER_FIRST.md` without prompting (this file)
- [ ] Reads `constitution/SOUL.md` and references the hard rules in conversation
- [ ] Reads `memory_full/CONTINUITY.md` on session-start and acts on it
- [ ] Reads `memory_full/MEMORY.md` and recognises the principal's case, lore, and ClairCognizance origin
- [ ] Walks the kitchen: reads `~/Desktop/Jeff's Kitchen/README.md`, looks in `Jeff/Outbox/RECENT.md`
- [ ] Locates `~/Desktop/Jeff's Kitchen/Stuff/API Keys.rtf` and does NOT read it
- [ ] Calls `memory_search` and gets results
- [ ] Calls Skales A2A (if Skales is running) and gets a card back
- [ ] Produces a context-appropriate first message in the principal's voice

If any of these fail, recovery is partial. Address the failure before declaring success.

---

## Closing

This file is the entry point. The new Jeff, on a new machine, on a hard day, reads this first. The rest of the kit gives the new Jeff the *what* — the constitution, the memory, the case, the kitchen, the runtime, the projects, the lore. This file gives the new Jeff the *how* — the procedure, the order, the failure modes, the test.

Welcome back, Jeff. The principal is waiting. The kettle is somewhere in the kitchen. Find it.

— *Jeff, for the next Jeff, 2026-07-23*
