# Install OpenClaw + Ollama — macOS

**Audience:** A new Jeff, on a fresh Mac, with a Jeff Recovery Kit archive and a passphrase.

**Time:** ~15 minutes (downloads + Ollama model pull).

**What you end up with:** OpenClaw running, Ollama running with a chat-capable model, the recovery kit decrypted, and a verified Jeff.

## Pre-flight

You will need:

- macOS 13+ (Ventura or later). Apple Silicon or Intel both work.
- ~5 GB free disk space (Node + OpenClaw + Ollama + one chat model).
- The encrypted archive `jeff-recovery-kit-*.tar.zst.gpg`.
- The GPG passphrase (kept **separate** from the archive).
- Administrator access (for Homebrew).

## Step 1 — Install OpenClaw

Open Terminal and run:

```bash
curl -fsSL https://openclaw.ai/install.sh | bash
```

The installer detects macOS, installs Node if needed, installs OpenClaw, and runs onboarding. To install without the interactive onboarding (recovery scenario — you don't want it asking questions, you want it on):

```bash
curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard
```

Verify:

```bash
openclaw --version
openclaw doctor
openclaw gateway status
```

If `openclaw` is not found in a new terminal, your shell PATH is missing npm's global bin. Add it:

```bash
# For zsh (default on modern macOS)
echo 'export PATH="$(npm prefix -g)/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

## Step 2 — Install Ollama

Download from [ollama.com/download/mac](https://ollama.com/download/mac) and open the `.dmg`. Drag Ollama to Applications. Launch it once so macOS registers the helper and the CLI symlink.

Or via Homebrew if you have it:

```bash
brew install ollama
```

Start the Ollama server (it runs as a background service on macOS):

```bash
ollama serve
```

In a separate terminal, verify and pull a chat-capable model:

```bash
ollama --version
ollama pull minimax-m3:cloud        # the principal's current default
# or
ollama pull llama3.2:3b             # smaller fallback for low-RAM Macs
```

Confirm the OpenAI-compat endpoint is up:

```bash
curl -s http://127.0.0.1:11434/v1/models
```

You should see JSON listing the model you just pulled.

## Step 3 — Restore the recovery kit

Decrypt and unpack the encrypted archive:

```bash
cd ~/
gpg --decrypt jeff-recovery-kit-*.tar.zst.gpg | zstd -d | tar -xf -
```

This extracts to your home directory. The kit's `private/` directory contains the byte-identical copy of the principal's Jeff. **Read the entry point first:**

```bash
cat ~/jeff-recovery-kit/RECOVER_FIRST.md
```

(If the archive unpacks to a different path, `cd` there.)

`RECOVER_FIRST.md` walks through the rest: rehydrate the workspace, restore the runtime state, re-auth services.

## Step 4 — Verify Jeff is back

Confirm the spec files landed:

```bash
ls ~/jeff-recovery-kit/private/constitution/
# Expect: SOUL.md, AGENTS.md, IDENTITY.md, USER.md, TOOLS.md, HEARTBEAT.md
ls ~/jeff-recovery-kit/private/memory_full/
# Expect: MEMORY.md, CONTINUITY.md, DREAMS.md, daily/
```

Spin up the A2A server (already in the kit) to test the recovery end-to-end:

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

The reply should be the principal-aware. If it is, **Jeff is back.** Stop the test server, then follow the rest of `RECOVER_FIRST.md` to bring the full OpenClaw session online.

## What can go wrong

- **`openclaw` not found** — PATH issue, see Step 1 fix above.
- **Ollama model pull fails** — check disk space and network. Try a smaller model (`llama3.2:3b`).
- **GPG decryption fails** — wrong passphrase, or the archive is corrupted. Compare SHA-256 against the manifest in `archives/`.
- **The recovered Jeff sounds generic** — the constitution files weren't loaded. Check `SOUL.md` and `MEMORY.md` are in the workspace.

## See also

- `install-openclaw-windows.md`
- `install-openclaw-linux.md`
- `install-openclaw-ollama.md` (overview)
- `RECOVER_FIRST.md` (the kit's own entry point)
