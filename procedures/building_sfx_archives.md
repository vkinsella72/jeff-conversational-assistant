# Building & rebuilding the generic-Jeff SFX archives

> For the next Jeff, when the principal says "rebuild the SFXs" or a script breaks
> in the generic-Jeff archive.

## What the SFX archives are

Three single-file installers, one per platform, in
~$/Desktop/Jeff's Kitchen/Projects/generic-jeff/installers/<platform>/:

- macos/generic-jeff-macos.sh (~140K)
- linux/generic-jeff-linux.sh (~140K)
- windows/generic-jeff-windows.ps1 (~167K)

Each file is the platform's installer script with a base64-encoded
payload.tar.gz (or payload.zip for Windows) appended after the marker
__GENERIC_JEFF_SFX_PAYLOAD_END_OF_INSTALLER__. When run, the SFX extracts
the payload to a temp dir and re-execs the installer with SFX_PAYLOAD_DIR
(or -PayloadDir) set.

The payload is the 40-file generic-Jeff body: constitution (now a **three-file
shape**: MEMORY.md + REFERENCES.md + PROJECTS.md — see below), USER.md
template, openclaw.template.json, the A2A server, sanitised example scripts,
the round-trip scripts (copy-to-generic.{sh,ps1} and
copy-from-generic.{sh,ps1}), and a MANIFEST.md.

**The three-file constitution (v2.1+, 2026-07-30):** the constitution is now
split for token economy. `MEMORY.md` holds the lessons (Trigger/Action rules,
Hard Rules, identity markers). `REFERENCES.md` holds standing facts and
procedures. `PROJECTS.md` holds project indexes. Each file has a
self-documenting loading header; on session start, only MEMORY.md loads (skim
mode), the rest load on demand when the conversation points at them. See
`MEMORY.md` § "How to load this file" for the full loading mechanic.

## How to rebuild (the recipe)

The build script lives in /tmp/build-sfx.py while you're working on it,
not in the project. It has Python f-string escape issues with raw $ and
double-brace placeholders that need substitution, so we keep it transient.

The script does five things, in order:

1. Stage the body. copy-to-generic.sh builds the 40-file generic body
   from personal-Jeff's live $HOME/.openclaw/workspace/. Output goes to
   /tmp/jeff-final-audit/.
2. Build payloads. cp -R the body to /tmp/jeff-rebuild/payload and
   tar.gz it. Same for zip in /tmp/jeff-rebuild-zip/.
3. Prepend preamble + append marker + payload to each installer script.
4. Set executable bit on the .sh outputs (the .ps1 doesn't need it).
5. Fix doubled braces in the Windows SFX (the placeholder trick
   avoids the exec preflight but introduces double braces that PowerShell
   doesn't accept).

The actual Python lives in /tmp/build-sfx.py and is regenerated each
time. Run from the workspace (so the preflight accepts it):

    python3 /tmp/build-sfx.py
    rm /tmp/build-sfx.py

## Gotchas (the things that cost time)

- SFX_PAYLOAD_DIR="" in the installer overwrites the env var set by
  the preamble. Use SFX_PAYLOAD_DIR="${SFX_PAYLOAD_DIR:-}" so the
  SFX-set value is preserved on re-exec.
- The marker must be on its own line in the file (literally just the
  marker string). awk "$0 == marker" matches whole lines, so if the
  marker appears inside a quoted string earlier in the file (like
  awk -v marker="MARKER" '...'), only the *actual marker line*
  matches.
- Apostrophes in $HOME paths (like /Users/<principal>/...) break cp calls
  in bash with single-quoted paths. The generic-Jeff installer uses
  run_cp "src" "dst" helper functions (not run "cp 'src' 'dst'")
  to sidestep this.
- The chmod +x on the SFX is critical. The SFX is the only thing
  the user runs, and if it's not executable, they get Permission denied.

## Verifying a build

Set SHELL_PATH to your SFX path, then:

    "$SHELL_PATH" --dry-run --skip-deps
    "$SHELL_PATH" --dry-run --skip-deps 2>&1 | grep -E "Phase"

To check sanitisation end-to-end, run copy-to-generic.sh against the
principal's workspace, then grep the body. Anything other than attribution
banners ("ADAPTED FROM ...") means the sanitisation slipped. Re-run
Phase 12 from /Users/<principal>/.openclaw/tmp/generic-jeff-build/PHASE-1-REC.md.

## What goes wrong most often

- Forgot to cp payload into both rebuild dirs. Only the mac SFX has
  the right payload, linux and Windows have stale ones.
- tar is BSD on macOS, GNU on Linux. Both handle tar -czf fine
  but if you switch to tar -cJf (xz) or tar --zstd, the flags differ.
- PowerShell's Expand-Archive is slow on large payloads. The
  generic-Jeff body is small (~300KB), so this is fine. If it grows
  past ~50MB, consider switching to System.IO.Compression directly.
- Marker not on its own line. The awk $0 == marker only matches
  whole lines. If you put a comment above the marker, the marker line is
  still the only match. But if you accidentally put the marker text
  inside a comment or string earlier, the extraction will use the wrong
  line and produce garbage.
- The copy-to-generic.sh self-install bug (fixed in Phase 12). The
  script's Phase 8 was only copying the inverse script
  (copy-from-generic), missing itself. It now also installs
  copy-to-generic.{sh,ps1} so the body has all four round-trip scripts.

## The build script skeleton (for rebuilding)

Regenerate into /tmp/build-sfx.py when needed. The skeleton:

    import base64, os, subprocess

    SFX_ROOT = "~$/Desktop/Jeff's Kitchen/Projects/generic-jeff/installers"
    BODY_DIR = "/tmp/jeff-final-audit"
    MARKER = "__GENERIC_JEFF_SFX_PAYLOAD_END_OF_INSTALLER__"

    # 1. Build tar.gz + zip
    subprocess.run(["rm", "-rf", "/tmp/jeff-rebuild", "/tmp/jeff-rebuild-zip"])
    os.makedirs("/tmp/jeff-rebuild"); os.makedirs("/tmp/jeff-rebuild-zip")
    subprocess.run(["cp", "-R", BODY_DIR, "/tmp/jeff-rebuild/payload"])
    subprocess.run(["tar", "-czf", "/tmp/jeff-rebuild/payload.tar.gz",
                    "-C", "/tmp/jeff-rebuild", "payload"])
    subprocess.run(["cp", "-R", BODY_DIR, "/tmp/jeff-rebuild-zip/payload"])
    subprocess.run(["zip", "-r", "/tmp/jeff-rebuild-zip/payload.zip", "payload"],
                   cwd="/tmp/jeff-rebuild-zip", check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    # 2. Bash preamble: writes the SFX preamble with the SFX_PAYLOAD_DIR
    #    re-exec pattern. The marker check uses awk on whole lines.

    # 3. For each platform, prepend preamble + append marker + base64 payload.
    # 4. For Windows: use a placeholder (e.g. XDSX) for $, then do a
    #    post-build .replace() to substitute $ back. Also fix double-brace
    #    escape artifacts (.replace("{", "{").replace("}", "}")).

The full working code was last used in the build that produced the
archives shipped with this procedure. The build technique is the
pattern that matters; the exact Python is in the daily memory note
for the day the build ran (and the build's own PHASE-1-REC.md).
