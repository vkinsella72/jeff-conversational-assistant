# Install OpenClaw + Ollama — Windows

**Audience:** A new Jeff, on a fresh Windows box, with a Jeff Recovery Kit archive and a passphrase.

**Time:** ~20 minutes (downloads + Ollama model pull + Windows-first-run friction).

**What you end up with:** OpenClaw running, Ollama running with a chat-capable model, the recovery kit decrypted, and a verified Jeff.

## Pre-flight

You will need:

- Windows 10 (build 19041+) or Windows 11. Native Windows is supported; WSL2 also works if you prefer the Linux procedure.
- ~5 GB free disk space (Node + OpenClaw + Ollama + one chat model).
- The encrypted archive `jeff-recovery-kit-*.tar.zst.gpg`.
- The GPG passphrase (kept **separate** from the archive).
- Administrator access (for the OpenClaw installer and Ollama).
- PowerShell 5.1+ (built-in) or PowerShell 7+ (`winget install Microsoft.PowerShell`).

**Two paths:** native Windows (recommended) or WSL2. WSL2 follows the Linux procedure after WSL is set up.

## Path A — Native Windows (recommended)

### Step 1 — Install OpenClaw

Open PowerShell **as Administrator** and run:

```powershell
iwr -useb https://openclaw.ai/install.ps1 | iex
```

The installer detects Windows, installs Node if needed, installs OpenClaw, and runs onboarding. To install without the interactive onboarding (recovery scenario):

```powershell
& ([scriptblock]::Create((iwr -useb https://openclaw.ai/install.ps1))) -NoOnboard
```

Verify in a **new** PowerShell window:

```powershell
openclaw --version
openclaw doctor
openclaw gateway status
```

If `openclaw` is not found, your PATH is missing npm's global bin. Add it for the current user:

```powershell
# Find npm's global prefix
npm config get prefix
# Add that path's "bin" to your user PATH (Settings → System → About → Advanced system settings → Environment Variables)
# Or in PowerShell:
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";" + (npm config get prefix) + "\bin", "User")
# Restart PowerShell
```

### Step 2 — Install Ollama

Download the Windows installer from [ollama.com/download/windows](https://ollama.com/download/windows) and run it. Ollama registers itself as a Windows service and starts automatically.

Verify in PowerShell:

```powershell
ollama --version
ollama pull minimax-m3:cloud
# or
ollama pull llama3.2:3b
```

Confirm the OpenAI-compat endpoint is up:

```powershell
curl http://127.0.0.1:11434/v1/models
```

If `curl` isn't found, use `irm` (Invoke-RestMethod):

```powershell
irm http://127.0.0.1:11434/v1/models
```

### Step 3 — Restore the recovery kit

You'll need `gpg` and `zstd` on Windows. The OpenClaw installer may have brought them; if not, install via:

```powershell
# GPG
winget install GnuPG.Gpg4win

# zstd
winget install zstd
```

Or use WSL2 — see Path B below.

Decrypt and unpack the archive in PowerShell:

```powershell
cd $HOME
gpg --decrypt jeff-recovery-kit-*.tar.zst.gpg | zstd -d | tar -xf -
```

This extracts to your home directory. **Read the entry point first:**

```powershell
cat ~/jeff-recovery-kit/RECOVER_FIRST.md
```

`RECOVER_FIRST.md` walks through the rest: rehydrate the workspace, restore the runtime, re-auth services.

### Step 4 — Verify Jeff is back

Confirm the spec files landed:

```powershell
Get-ChildItem ~/jeff-recovery-kit/private/constitution/
# Expect: SOUL.md, AGENTS.md, IDENTITY.md, USER.md, TOOLS.md, HEARTBEAT.md
Get-ChildItem ~/jeff-recovery-kit/private/memory_full/
```

Spin up the A2A server to test the recovery end-to-end:

```powershell
cd ~/jeff-recovery-kit/private/recovery/public-archive/
python scripts/jeff_a2a_server.py --spec . --port 3001 --label recovered-jeff --model minimax-m3:cloud
```

In another PowerShell, hit it:

```powershell
$body = '{"id":"recovery-test","message":"Who is the principal?","from":"verify"}'
Invoke-RestMethod -Method Post -Uri http://127.0.0.1:3001/api/a2a/message -ContentType "application/json" -Body $body
```

The reply should be the principal-aware. **Jeff is back.** Stop the test server, then follow the rest of `RECOVER_FIRST.md`.

## Path B — WSL2

If you prefer Linux-on-Windows (more familiar for Unix-style shell commands):

```powershell
# Install WSL2 + Ubuntu
wsl --install -d Ubuntu

# Restart Windows, set up Ubuntu user, then inside Ubuntu:
curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard
curl -fsSL https://ollama.com/install.sh | sh
ollama pull minimax-m3:cloud
```

Then follow the Linux procedure (`install-openclaw-linux.md`) from Step 3 onwards.

## What can go wrong

- **`openclaw` not found** — PATH issue, see Step 1 fix.
- **PowerShell execution policy blocks the installer** — run `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` first.
- **Ollama model pull fails** — check disk space. Try `llama3.2:3b`.
- **GPG decryption fails** — wrong passphrase, or corrupted archive. Compare SHA-256 against the manifest in `archives/`.
- **Path with spaces** — `~/Jeff's Kitchen/` (the principal's setup) has an apostrophe; quote paths in PowerShell: `cd "$HOME/Jeff's Kitchen/..."`.
- **Antivirus flags Ollama** — Ollama is safe; add an exception if your AV is overzealous.

## See also

- `install-openclaw-macos.md`
- `install-openclaw-linux.md`
- `install-openclaw-ollama.md` (overview)
- `RECOVER_FIRST.md` (the kit's own entry point)
