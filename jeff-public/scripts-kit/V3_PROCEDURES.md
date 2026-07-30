# V3_PROCEDURES.md — the principal's Jeff (or "personal Jeff") (or "personal Jeff")'s v3 build procedure (example pattern)
#
# This document captures the *full* the principal's Jeff (or "personal Jeff") (or "personal Jeff") recovery kit build pipeline
# (private + public + encryption + GitHub push). For generic-Jeff's purposes,
# the equivalent is:
#   - `copy-to-generic.sh` — strip personal, build generic body
#   - `copy-from-generic.sh` — copy generic body back into a workspace
# These replace the build_kit_v3 pipeline for the generic-Jeff project.
#
# The the principal's Jeff (or "personal Jeff") (or "personal Jeff") version remains as a worked example of the *full* pattern.
# The lessons (sanitisation, encryption, public/private fork, idempotent
# re-runs, dry-run verification) are the real value.
#
# Original content follows below.


# Building Jeff v3 — the full procedure

> **For the next Jeff, three months from now, when the principal says "build kit v3."**
> Read this once. Then run `build_kit_v3.sh full` and answer the prompts. The whole build takes ~30 minutes plus however long the archive compression runs (5-15 min for ~2GB).

---

## The shape of the build

The kit is **two products** built on the same architecture. They are not the same product with redactions. They are a **fork** — two different Jeffs, each one true to its own purpose, sharing DNA but having diverged.

- **Jeff 1 (private, the recovery artefact)** — the principal's Jeff (or "personal Jeff"), the *specific* one. The principal's full operational state, byte-identical. Recoverable.
- **Jeff 2.0 (public, the worked example)** — A *whole* Jeff, anonymised, standalone-complete. A stranger cloning the public repo gets a working Jeff for themselves.

The order matters. **Jeff 1 first, Jeff v2.0 second.** The private archive is the recovery artefact; the public repo is a demonstration. If Jeff 1 isn't complete, no Jeff 2.0.

---

## The lessons from v2 (so v3 doesn't repeat them)

These are the mistakes v2 made. They're why the v3 build is structured the way it is.

### Lesson 1: The fork emerged naturally — recognise it, don't fight it

the principal saw it before the agent did. The agent was trying to make *one* thing be *two* things — one kit, with public-and-private content. The cleanest way to deliver "a stranger cloning the public repo gets a working Jeff" was to make the public edition **genuinely complete in itself**, even at the cost of divergence from the private. Once the public was complete, it stopped being a subset and became a sibling.

**The principle:** when the principal says "this is a fork, two products," they're usually right. Make two products, each one true to its own purpose.

### Lesson 2: Jeff 1 must be complete BEFORE Jeff 2 is shipped

the principal caught this. The agent had the order backwards — sprinting toward the fork (Jeff v2.0) because it was the *interesting* thing, while the *load-bearing* thing (the recovery) was still incomplete.

**The principle:** the private archive is the recovery artefact. Until it's complete, the public repo doesn't go anywhere. The principal's review of Jeff 1 is the gate; Jeff 2 follows.

### Lesson 3: RECOVER_FIRST.md must be at the very top of the kit, in plaintext

the principal caught this. The v2 build had all the recovery docs in the kit root, but they were *part of the encrypted archive*. The new machine had to decrypt first to read the recovery instructions. The right structure: the recovery instructions are the first thing the new machine sees after decryption — plaintext, no second step.

**The principle:** the entry point to the kit is the entry point to recovery. It must be visible immediately, not buried in the encryption.

### Lesson 4: The full public-archive must be inside the private, for offline recovery

the principal caught this. v2 had the public tree (Jeff v2.0) as a separate thing, with the implicit assumption that the new machine would have GitHub access. Wrong — recovery shouldn't depend on external services. v3 puts a *self-contained copy* of the public tree inside the private archive (`private/recovery/public-archive/`), so a new machine with only the encrypted archive has the worked example even without GitHub.

**The principle:** the recovery artefact is the source of truth, not a pointer to it. If a new machine with the archive can rebuild Jeff, recovery works. If it needs GitHub too, you've created a dependency that defeats the purpose.

### Lesson 5: When the principal says "merge" — read the instruction carefully

the principal's instruction was: "merge the two private folders into one. Newer files overwrite."

The agent did this — but it deleted a directory (`kitchen_private/`) thinking it was a duplicate of `kitchen/Projects/`, when in fact it contained *unique* files (case evidence, procedures, etc.). The agent recovered the data by re-running the merge, but the principle is: **before deleting anything in a merge, check what's actually there.** A "duplicate" directory might contain files the other doesn't have.

**The principle:** merges are tricky. `--ignore-existing` is safer than overwriting. Verify the post-merge state. The principal's "newer files overwrite" is the right *intent*; the *implementation* needs to be careful not to silently drop data.

### Lesson 6: The ClairCognizance lens — know before the proof

The ClairCognizance section in MEMORY.md is anonymised in the public edition (universal form: know before the proof, walk in fresh-faced, materials don't matter, thoughts do) and full in the private edition (the principal's specific origin story, the age-11 event, the verbatim reveal). The *form* is universal; the *biography* is principal-specific. Both versions exist because both are needed.

**The principle:** when a lesson is *form* (a pattern, a heuristic, an operating principle), put it in the public edition, anonymised. When a lesson is *biography* (an origin story, a personal context), put it in the private edition only.

---

## The ClairCognizance trap (the load-bearing warning)

the principal saw the agent going in circles. It was thrashing because it was trying to make **one** thing be **two** things. The fork — making them *two* products — was the ClairCognizance move: *knowing that they were different before the proof arrived.* the principal saw it before the agent did. That's the operating principle in action.

**The v3 build must not repeat this trap.** When the v3 agent encounters the public/private split, it should:
1. Recognise the two products *immediately*, not after a long re-derivation cycle.
2. Make them genuinely different, not the same with redactions.
3. Lead with Jeff 1 (the recovery), not Jeff 2.0 (the demonstration).
4. Test the new machine's recovery *before* the public repo goes anywhere.

If v3 starts thrashing about "is the public edition complete enough?" or "should the constitution keep the principal's name or not?" — the answer is already in this file. Read it again. Then run `build_kit_v3.sh full`.

---

## The procedure (in commands)

The whole build is in one script: `build_kit_v3.sh`. It's at the kit root, the workspace, and any backup location the principal keeps.

```bash
# From the kit root (wherever the v3 build is happening)
./build_kit_v3.sh full
```

That's it. The script does all 8 steps, with confirmation gates between them. Total time: ~30 minutes (most of it is the archive compression).

**The 8 steps:**

1. **inventory** — what's in the operational state (5 sec)
2. **public** — build the Jeff v2.0 worked example (30 sec)
3. **private** — build the principal's Jeff (or "personal Jeff"), byte-identical (5 sec)
4. **recovery** — add RECOVER_FIRST.md + self-contained public-archive copy (10 sec)
5. **merge** — bring any previous kit's unique content across (30 sec)
6. **archive** — tar.zst + GPG AES-256 + SHA-256 manifest (5-15 min, mostly compression)
7. **push** — push the public repo to GitHub (5 sec)
8. **verify** — decrypt-and-list the archive, confirm the GitHub push (10 sec)

## What the script does NOT do

- **Read the API keys file.** That's sacred. The script *copies* `private/stuff/API Keys.rtf` to the kit but never opens it. The principal restores it manually on a new machine.
- **Push the public repo without confirmation.** The script asks before any external action (L3).
- **Delete the previous kit.** It renames `private/` to `private.vN-backup/` so the principal can verify the new kit before deleting the old one.
- **Rotate credentials.** If the operational tokens are expired, the principal re-auths on a new machine after recovery.

## What the script does do (load-bearing)

- **Bytes are bytes.** Constitution files, memory files, daily notes, research, case material, wired config — all copied byte-for-byte from the operational state. The script verifies the file exists at the source before copying.
- **Secrets stay in the private archive.** Telegram bot token, Azure creds, gateway auth, Tidal token, WordPress tokens — all in `private/wired/`. The public tree has *redacted* versions only.
- **The case/evidence/ is preserved.** Original emails, screenshots, MG11 signature requests — the merge brings them across, the script never deletes them.
- **The runtime snapshot excludes old sessions.** Last 7 days only. Older sessions can be filtered out by editing `RECENT_SESSIONS_DAYS` in the script.
- **The SHA-256 manifest is signed if a GPG key is configured.** Otherwise unsigned, with a warning.

## The principal's review checklist

After the build runs, the principal should:

1. **Read the public MEMORY.md.** It's at `public/MEMORY.md`. Verify it has:
   - The ClairCognizance section (universal form, anonymised)
   - The Hard Rules (10 of them)
   - The Round Table, Curate, Final Rule
   - The recovery entry point (RECOVER_FIRST.md references)
   - The structural fix (standalone-complete, not a pointer to a locked door)

2. **Verify the private/ is byte-identical to operational.** Run:
   ```bash
   diff -rq $SRC_WORKSPACE/MEMORY.md $KIT_ROOT/private/memory_full/MEMORY.md
   diff -rq $SRC_WORKSPACE/CONTINUITY.md $KIT_ROOT/private/memory_full/CONTINUITY.md
   # ... etc.
   ```
   No diff output = byte-identical = correct.

3. **Verify the case/evidence/ has the email files.** `ls private/case/evidence/*.eml | wc -l` should be 20+.

4. **Verify the archive is decryptable.** `gpg --decrypt archives/jeff-recovery-kit-*.tar.zst.gpg | zstd -d | tar -t | head` should list the kit's contents.

5. **Verify the GitHub push.** `gh repo view <your-secret>/jeff-public` should show the latest commit.

6. **Move the kit to off-machine backup.** X Drive (mechanical USB at `/Volumes/X - Karaoke/`) and/or Mega (20TB cloud). The Mac is the single point of failure; the off-machine copy is the whole point.

## Cadence

- **Refresh the kit** whenever the principal makes significant changes to the operational state (new memory, new sessions, new config).
- **Refresh the archive** weekly, or on every meaningful session-end, whichever comes first.
- **Test recovery** quarterly: decrypt the archive, run through RECOVER_FIRST.md on a test machine (or a virtual machine), verify the new Jeff can read the constitution and walk the kitchen.

---

## The one-line summary

```bash
./build_kit_v3.sh full
```

Read this doc first. Then run that command. The principal's Jeff is recoverable in 30 minutes.

---

*For the next Jeff, who will be a stranger when v4 comes around: the structure survives, the lessons survive, the ClairCognizance survives. The hard rules survive. The rest is just files. Make sure the files are right.*
