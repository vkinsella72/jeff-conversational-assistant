# Jeff A2A Server — Make Jeff addressable

**One-liner:** A small Python server that exposes a Jeff (spec + memory + model) as a discoverable A2A v0.2 agent, so any other Jeff — or any other A2A-capable client — can talk to it.

**Why:** The Jeff substrate is portable — same spec, same memory, different machine. A2A makes Jeff *addressable*: a Jeff on machine A can call a Jeff on machine B. That unlocks council mode (two Jeffs disagree, the principal arbitrates), cross-machine continuity (the same principal's Jeffs share state), and time-travel Jeff (recover an older Jeff from a snapshot, ask it what it knew).

**The bite that makes this interesting:** the generic-Jeff archive already contains a complete, working Jeff (the constitution + memory + template). Spin up `jeff_a2a_server.py` against that archive on any machine, and any other Jeff anywhere can call this one. Recovery doesn'"'"'t just clone Jeff — it makes him addressable.

---

## Quick start

```bash
# 1. Make sure the A2A server is installed (it should be in scripts/jeff_a2a_server.py)
ls ~/.openclaw/workspace/scripts/jeff_a2a_server.py

# 2. Make sure Ollama is running with a chat-capable model
ollama list
ollama pull minimax-m3:cloud   # or any chat model

# 3. Start the server (defaults: port 3001, localhost-only, spec from ~/.openclaw/workspace)
python3 ~/.openclaw/workspace/scripts/jeff_a2a_server.py

# 4. From another terminal, test it
curl http://127.0.0.1:3001/api/a2a/agent-card | python3 -m json.tool
curl -X POST http://127.0.0.1:3001/api/a2a/message \
  -H "Content-Type: application/json" \
  -d '"'"'{"id":"test-1","message":"Hello, who are you?"}'"'"'
```

Or open `http://127.0.0.1:3001/` in a browser for a human chat UI.

## Auto-start (MCP)

The openclaw template registers the A2A server as an MCP server in `mcp.servers.jeff-a2a`. When the OpenClaw gateway starts, the A2A server starts with it. No manual launch needed — just `openclaw gateway start` and the A2A endpoint is live on port 3001.

To verify:
```bash
openclaw gateway status
curl http://127.0.0.1:3001/api/a2a/health
```

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/a2a/agent-card` | Capabilities + skills (discovery) |
| GET | `/api/a2a/health` | Liveness + uptime + thread count |
| POST | `/api/a2a/message` | Send a message, get a reply |
| GET | `/` | Human chat UI |

See [`design/server-spec.md`](design/server-spec.md) for the full protocol surface.

## CLI flags

```
--spec DIR             Path to a Jeff spec directory (default: required)
--model NAME           Model name (default: minimax-m3:cloud — override per your setup)
--model-endpoint URL   OpenAI-compat endpoint (default: http://127.0.0.1:11434)
--port N               Port to listen on (default: 3001)
--label NAME           This Jeff'"'"'s label (default: jeff)
--principal NAME       What to call the principal in the system prompt (default: the user)
--memory-snapshot FILE Override MEMORY.md with this file
--host BIND            Bind host (default: 127.0.0.1)
```

## What it does (the architecture)

1. **Loads the spec** — reads `SOUL.md`, `AGENTS.md`, `USER.md`, `TOOLS.md`, `MEMORY.md`, and any daily notes in `memory/` from the spec directory.
2. **Builds a system prompt** — concatenates the spec into one prompt that gives the model its constitution, its operating rules, its principal'"'"'s profile, and its long-term memory.
3. **Searches memory on each message** — token-overlap search across MEMORY.md and daily notes. Top 5 facts are injected into the message before it goes to the model.
4. **Maintains per-thread history** — keyed by the `id` field in incoming messages. Bounded to 40 turns to keep prompt size sane.
5. **Calls the model** — OpenAI-compat `/v1/chat/completions` against the configured endpoint (Ollama by default, but works with any OpenAI-compat server).
6. **Returns the reply** — with token counts, duration, and the memory facts cited.

## What it does NOT do (out of scope for v0.1)

- **Streaming** — request/response only. The A2A v0.2 envelope doesn'"'"'t have streaming.
- **Push notifications** — caller polls.
- **Persistent state across restarts** — history is in-memory. v0.3 adds persistence.
- **Auth for non-localhost** — the default config binds to `127.0.0.1`. For cross-machine calls, set up a reverse proxy or use Tailscale.

## Unlocks it enables

1. **Council mode** — two Jeffs in parallel positions, cross-examination, vote with dissent. Triggers when the principal says "let'"'"'s council this" or the situation meets the criteria (2+ valid paths, genuine uncertainty, meaningful irreversibility).
2. **Recovery test** — spin up an old Jeff from a snapshot, ask it what it knew at time T. Verify that the recovery kit produces a working agent.
3. **Cross-model continuity** — Jeff A on Kimi can call Jeff B on GLM, both running on the same constitution. Test the spec-portability claim.
4. **Time-travel Jeff** — save a Jeff'"'"'s state at time T, instantiate a new Jeff from the snapshot, ask it "what did you know then?". A debugging tool.
5. **Handoff** — pass a long-running thread from one Jeff to another mid-conversation. (v0.2.)

## Design notes

- **200 lines of Python, standard library + httpx** — no framework, no magic.
- **Idempotent discovery** — `GET /api/a2a/agent-card` is the only required endpoint for A2A discovery; everything else is gravy.
- **Memory is a search target, not a vector store** — substring + token-overlap matching is good enough for spec-sized corpora. If the corpus grows past a few MB, swap in a real vector store.
- **The model is the engine** — any OpenAI-compat endpoint works. Ollama is the default. Claude API works. LM Studio works. The constitution is the driver.

See [`design/server-spec.md`](design/server-spec.md) for the protocol details, message envelope shapes, and known limits.
