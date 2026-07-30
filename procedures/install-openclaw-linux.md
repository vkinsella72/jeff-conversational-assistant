# Install OpenClaw + Ollama — Linux

**Audience:** A new Jeff, on a fresh Linux box, with a Jeff Recovery Kit archive and a passphrase.

**Time:** ~15 minutes (downloads + Ollama model pull).

**What you end up with:** OpenClaw running, Ollama running with a chat-capable model, the recovery kit decrypted, and a verified Jeff.

## Pre-flight

You will need:

- A modern Linux distribution (Ubuntu 22.04+, Debian 12+, Fedora 39+, Arch, or any distro with systemd).
- ~5 GB free disk space (Node + OpenClaw + Ollama + one chat model).
- The encrypted archive `jeff-recovery-kit-*.tar.zst.gpg`.
- The GPG passphrase (kept **separate** from the archive).
- `sudo` access (or root) for system-level installs. A local-prefix install is possible without root — see Step 1 alternative.
- Basic build tools (`curl`, `gpg`, `zstd` are required; `tar` is built-in).

**Distro note:** these instructions use Ubuntu/Debian paths. Adapt for your package manager (`dnf` on Fedora, `pacman` on Arch, etc.). The OpenClaw and Ollama installers are distro-agnostic.

## Step 1 — Install OpenClaw

```bash
curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard
```

The installer detects Linux, installs Node if needed, installs OpenClaw, and skips onboarding (recovery scenario — you don't want it asking questions).

Verify:

```bash
openclaw --version
openclaw doctor
openclaw gateway status
```

If `openclaw` is not found, your shell PATH is missing npm's global bin. Add it:

```bash
# bash
echo 'export PATH="$(npm prefix -g)/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# zsh
echo 'export PATH="$(npm prefix -g)/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

**Alternative — local-prefix install (no root required):**

If you can't or don't want to use sudo:

```bash
curl -fsSL https://openclaw.ai/install-cli.sh | bash
```

This installs Node + OpenClaw under `~/.openclaw/` (no system-wide changes). Use the same `openclaw` commands afterwards.

## Step 2 — Install Ollama

The Ollama one-liner covers both Linux and macOS:

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

This installs Ollama as a systemd service and starts it. Verify:

```bash
systemctl status ollama          # service running?
ollama --version
ollama pull minimax-m3:cloud
# or
ollama pull llama3.2:3b
```

Confirm the OpenAI-compat endpoint is up:

```bash
curl -s http://127.0.0.1:11434/v1/models
```

You should see JSON listing the model you just pulled.

**If you don't have systemd** (containers, WSL, etc.):

```bash
ollama serve &                  # run in background
ollama pull minimax-m3:cloud
```

## Step 3 — Restore the recovery kit

Confirm `gpg` and `zstd` are installed:

```bash
gpg --version
zstd --version
```

If missing, install via your package manager:

```bash
# Ubuntu / Debian
sudo apt install gpg zstd

# Fedora
sudo dnf install gnupg zstd

# Arch
sudo pacman -S gnupg zstd
```

Decrypt and unpack the archive:

```bash
cd ~/
gpg --decrypt jeff-recovery-kit-*.tar.zst.gpg | zstd -d | tar -xf -
```

This extracts to your home directory. **Read the entry point first:**

```bash
cat ~/jeff-recovery-kit/RECOVER_FIRST.md
```

`RECOVER_FIRST.md` walks through the rest: rehydrate the workspace, restore the runtime, re-auth services.

## Step 4 — Verify Jeff is back

Confirm the spec files landed:

```bash
ls ~/jeff-recovery-kit/private/constitution/
# Expect: SOUL.md, AGENTS.md, IDENTITY.md, USER.md, TOOLS.md, HEARTBEAT.md
ls ~/jeff-recovery-kit/private/memory_full/
# Expect: MEMORY.md, CONTINUITY.md, DREAMS.md, daily/
```

Spin up the A2A server to test the recovery end-to-end:

```bash
cd ~/jeff-recovery-kit/private/recovery/public-archive/
python3 scripts/jeff_a2a_server.py \
  --spec . \
  --port 3001 \
  --label recovered-jeff \
  --model minimax-m3:cloud
```

In another terminal, hit it:

```bash
curl -s -X POST http://127.0.0.1:3001/api/a2a/message \
  -H "Content-Type: application/json" \
  -d '{"id":"recovery-test","message":"Who is the principal?","from":"verify"}' | python3 -m json.tool
```

The reply should be the principal-aware. **Jeff is back.** Stop the test server, then follow the rest of `RECOVER_FIRST.md`.

## What can go wrong

- **`openclaw` not found** — PATH issue, see Step 1 fix.
- **`systemctl status ollama` shows the service failed** — check `journalctl -u ollama` for the actual error. Common: port 11434 already in use, or no GPU drivers for the model you pulled.
- **Ollama model pull fails** — check disk space. Try a smaller model (`llama3.2:3b`).
- **GPG decryption fails** — wrong passphrase, or corrupted archive. Compare SHA-256 against the manifest in `archives/`.
- **No GUI / headless server** — all of these commands work over SSH. The A2A server's chat UI is browser-based but optional; the API works headless.
- **SELinux blocks Ollama** (Fedora/RHEL) — `sudo setsebool -P use_nfs_home_dirs 1` or grant Ollama the right context.

## See also

- `install-openclaw-macos.md`
- `install-openclaw-windows.md`
- `install-openclaw-ollama.md` (overview)
- `RECOVER_FIRST.md` (the kit's own entry point)
