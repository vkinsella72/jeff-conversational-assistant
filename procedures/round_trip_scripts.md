# Round-trip scripts: copy-to-generic & copy-from-generic

> For the next Jeff: when a fresh principal installs generic-Jeff and then
> wants to swap their personal Jeff in, or when personal-Jeff's body needs to
> be re-extracted to generic.

## The two scripts

In `~/Desktop/Jeff's Kitchen/Projects/generic-jeff/scripts/`:

- `copy-to-generic.sh` (+ `.ps1`) — personal-Jeff (or any personal Jeff) →
  generic body. The "stripping" direction.
- `copy-from-generic.sh` (+ `.ps1`) — generic body → principal's
  `~/.openclaw/workspace/`. The "wake up with no memory" direction.

The `.ps1` versions are the Windows PowerShell equivalents.

## How copy-to-generic works (the stripper)

Nine phases, in order:

1. **Sanity checks** — source workspace exists, public/ template dir
   exists. The script lives in the project root, and `SCRIPT_DIR` resolves
   to that root. `PUBLIC_TEMPLATE_DIR` is $SCRIPT_DIR/public (i.e.
   `~/Desktop/Jeff's Kitchen/Projects/generic-jeff/public`).
2. **Build destination** — create $DST (default `./generic-jeff-build`).
3. **Constitution files** — copy AGENTS.md, SOUL.md, MEMORY.md, TOOLS.md,
   HEARTBEAT.md, RECOVER_FIRST.md from the template (always from template,
   never from the source's live versions).
4. **Templated personal files** — USER.md, IDENTITY.md, README.md,
   kitchen_menu.md, COMPONENT_MAP.md, CAPABILITY_MAP.md,
   AI_Agent_Portable_Playbook.md. Also always from template.
5. **openclaw.template.json** — install at `wired/template/`.
6. **A2A server** — install `scripts/jeff_a2a_server.py`.
7. **Sanitised example scripts** — install `scripts/examples/` and
   `scripts/examples-kit/`.
8. **Self + inverse round-trip scripts** — install copy-to-generic.sh,
   copy-to-generic.ps1, copy-from-generic.sh, copy-from-generic.ps1.
   (Self-install was a bug in Phase 12; it's now fixed.)
9. **MANIFEST.md** — write a build manifest with timestamp.

**Excluded patterns** (logged but never copied from source):

- `Stuff` (API keys, sacred files)
- `Jeff/CONTINUITY.md` (session state)
- `memory/vault`, `memory/skales.md`, `memory/sidecar.md` (private memory)

## How copy-from-generic works (the installer)

Six phases, in order:

1. **Pre-flight** — source `generic-jeff-build/` exists.
2. **Defensive check** — refuse to overwrite $DST (default
   $HOME/.openclaw/workspace) if it already has content, unless
   `--backup` is passed. This replaces the old `*<principal>*|*doe*`
   pattern check (which was the principal-specific) with a generic content check.
3. **Back up** (if --backup) — rename existing dst to
   `dst.backup.<timestamp>`.
4. **Ensure dst exists** — `mkdir -p`.
5. **Copy body** — `cp -R src/. dst/`.
6. **Set executable bits** on all `.sh` files in `dst/scripts/`.
7. **Verify A2A server** is at the expected path.

PowerShell version uses `Get-ChildItem` to test for content, and
`Rename-Item` for the backup. Same six phases, same logic.

## CLI flags (both scripts)

    copy-to-generic.sh [SRC] [DST]   # both optional
        --dry-run        # show what would happen, don't write
        --help | -h      # print help

    copy-from-generic.sh [SRC] [DST]
        --dry-run        # show what would happen
        --backup         # back up existing dst before overwriting
        --help | -h

PowerShell equivalents use `-DryRun`, `-Backup`, `-Source`, `-Destination`.

## The /tmp build-sfx.py pattern (companion procedure)

The SFX archives embed the output of `copy-to-generic.sh`. Rebuilding
the SFXs is documented in `procedures/building_sfx_archives.md`. The
two procedures share the `BODY_DIR = /tmp/jeff-final-audit` staging
location.

## Things that bit me (lessons)

- **`run_cp`/`run_mkdir`/`run_chmod` helpers, not `run "cp 'src' 'dst'"`.**
  The original `run()` function used `eval $@` on a string, which
  breaks on apostrophes in $HOME paths (`/Users/<principal>/...`). The fix
  was to split the helper functions and pass real args. See the
  building_sfx_archives procedure for the full gotcha list.

- **The SFX_PAYLOAD_DIR reset bug.** The installer had
  `SFX_PAYLOAD_DIR=""` which clobbered the env var set by the SFX
  preamble. Fix: `SFX_PAYLOAD_DIR="${SFX_PAYLOAD_DIR:-}"`.

- **Defensive check rewrite (Phase 12).** The old check looked at
  $HOME for `*<principal>*|*doe*`. That was a personal-name check.
  Total sanitisation required the check to be content-based instead:
  refuse if the destination already has files, unless `--backup` is
  passed. The new check is the actual safety condition, with no
  personal references.

- **Self-install bug (Phase 12).** Phase 8 of copy-to-generic.sh was
  only installing the inverse script, missing itself. The body came
  out with copy-from-generic.sh + .ps1 but not copy-to-generic.sh + .ps1.
  The fix: install all four. Now the body is self-contained.

## Verifying the round-trip

The verifying recipe:

1. Build the generic body into a clean staging dir (e.g. `/tmp/audit`).
2. Run `copy-to-generic.sh` with the principal's workspace as the
   source. The two arguments are `SRC DST` — workspace first, then
   the staging dir.
3. `grep -rE "<principal>|doe"` on the staging dir. Anything other
   than attribution banners means the sanitisation slipped.
4. `ls` the staging dir and confirm all four round-trip scripts are
   present (`copy-to-generic.{sh,ps1}`, `copy-from-generic.{sh,ps1}`).
5. To test the SFX end-to-end, set `HOME` to a `mktemp -d` directory
   and run the macOS or Linux SFX with `--skip-deps --skip-model`.
   The SFX should install the body to `HOME/.openclaw/workspace/`
   with 18+ files.

The full commands are in the verifying section of
`procedures/building_sfx_archives.md`. They're not duplicated here
because the literal shell snippets trip the exec preflight (a
vigilant guard against accidental shell injection in Python).

## What this procedure is NOT

This is the round-trip *scripts* procedure. The *SFX build* pipeline
lives in `building_sfx_archives.md`. The *sanitisation audit* lives
in PHASE-1-REC.md (Phase 12 section). The *openclaw.json template*
lives in `wired/template/openclaw.template.json` and is documented
inline.

## File map (where things actually live)

- Scripts: `~/Desktop/Jeff's Kitchen/Projects/generic-jeff/scripts/`
- This procedure: `~/Desktop/Jeff's Kitchen/Projects/generic-jeff/procedures/round_trip_scripts.md`
- Public template: `~/Desktop/Jeff's Kitchen/Projects/generic-jeff/public/`
- A2A server: `~/Desktop/Jeff's Kitchen/Projects/generic-jeff/Jeff A2A Server/scripts/jeff_a2a_server.py`
- Installers: `~/Desktop/Jeff's Kitchen/Projects/generic-jeff/installers/<platform>/`
- Build records: `/Users/<principal>/.openclaw/tmp/generic-jeff-build/PHASE-1-REC.md`
