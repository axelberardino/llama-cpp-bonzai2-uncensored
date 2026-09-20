# Bonsai 2 27B Uncensored local server for Claude Code

# TL;DR

Immediately launch the `dealignai/Bonsai-2-27B-Ternary-CRACK-GGUF` model in one line:
```sh
./run.sh
```

Immediately launch a special claude using this model:
```sh
./claude_server.sh
./claude_client.sh
```

# What is it

This repository is a fork of [llama.cpp](https://github.com/ggml-org/llama.cpp), based on the [PrismML](https://github.com/PrismML-Eng/llama.cpp) `prism` branch that adds the low-bit `PQ2_0` ternary format used by the [Bonsai](https://huggingface.co/collections/prism-ml/bonsai) models. On top of that it adds what is needed to use a local Bonsai model from [Claude Code](https://code.claude.com):

- `llama-server` speaks the Anthropic Messages API (`POST /v1/messages`, `POST /v1/messages/count_tokens`, SSE streaming, `tool_use` and `tool_result` blocks, system prompts, stop reasons), including the mid-conversation system messages that Claude Code sends.
- A new `--upstream-url` option turns `llama-server` into a gateway: requests for the local model are served on the machine, requests for any other model (Claude Opus, Sonnet, Fable, ...) are forwarded unchanged to `https://api.anthropic.com` with the client's own credentials. Claude Code then keeps its normal claude.ai login and the local model shows up as one more entry in the `/model` picker.

The model used is [dealignai/Bonsai-2-27B-Ternary-CRACK-GGUF](https://huggingface.co/dealignai/Bonsai-2-27B-Ternary-CRACK-GGUF), file `Bonsai-2-27B-PQ2_0-CRACK.gguf` (about 7.2 GB).

## Requirements

- macOS on Apple Silicon (Metal) or Linux. The scripts build with the CMake defaults of this fork: Metal on macOS, OpenSSL enabled (needed for the HTTPS upstream).
- `cmake`, a C++17 compiler, `curl`, and about 8 GB of disk for the model.
- RAM: the model takes about 7 GB. The KV cache costs about 64 KB per token of context, so 32k of context adds 2 GB and 128k adds 8 GB.

## Scripts

Both scripts live at the repository root, are safe to re-run, and do the same preparation steps:

1. Download `Bonsai-2-27B-PQ2_0-CRACK.gguf` into the repository root if it is not there yet (resumable, retried).
2. Build `./build/bin/llama-server` if it is missing.
3. Start the server on `127.0.0.1:8080`.

Any extra arguments are passed through to `llama-server`, for example `./run.sh --verbose`.

### `run.sh`: plain local server

```shell
./run.sh
```

Starts a standard 32k-context server with the OpenAI and Anthropic compatible endpoints. Use it when you only want to talk to the local model, for instance with `curl` or any OpenAI or Anthropic client pointed at `http://127.0.0.1:8080`.

### `claude_server.sh`: gateway for Claude Code

```shell
./claude_server.sh
```

Starts the server as a Claude Code gateway:

- 128k context, 2 slots (Claude Code sends a title request in parallel with the main one).
- The model is exposed under the alias `bonsai-2-27b`.
- `--upstream-url https://api.anthropic.com`: anything that is not `bonsai-2-27b` is forwarded to Anthropic.

The script also rebuilds `llama-server` when the existing binary predates the `--upstream-url` option, and before launching it prints the Claude Code settings to add (the content of `env.txt`).

## Connecting Claude Code

Two launcher scripts point Claude Code at the gateway without touching `~/.claude/settings.json`, see [Claude Code launchers](#claude-code-launchers). To make the gateway the default for plain `claude` instead, add the `env` block printed by `claude_server.sh` to `~/.claude/settings.json`:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://127.0.0.1:8080",
    "ANTHROPIC_CUSTOM_MODEL_OPTION": "bonsai-2-27b",
    "ANTHROPIC_CUSTOM_MODEL_OPTION_NAME": "Bonsai 27B (local)",
    "ANTHROPIC_CUSTOM_MODEL_OPTION_DESCRIPTION": "Local llama-server gateway on 127.0.0.1:8080"
  }
}
```

Then start `claude` as usual. In `/model` you get the regular Claude models plus "Bonsai 27B (local)". Selecting it routes the session to the local server, selecting a Claude model goes to Anthropic through the same gateway.

Notes:

- Do not set `ANTHROPIC_API_KEY`. With a key set Claude Code drops the claude.ai login and the cloud models stop working through the gateway.
- Do not start `llama-server` with `--api-key` in this setup: it would reject the Anthropic token before forwarding it.
- Claude Code only reaches Anthropic through the gateway while it points at it, so keep `claude_server.sh` running, or remove the `env` block to go back to the direct connection.
- The first turn of a session processes the whole Claude Code prompt (often 25k to 50k tokens) and can take a few minutes on a 27B model. Later turns reuse the prompt cache. See the lean profile below to shrink it.

## Claude Code launchers

Both scripts pass extra arguments through to `claude`, for example `./claude_client.sh --model bonsai-2-27b` to start directly on the local model, or `./claude_client.sh -c` to continue the last session.

### `claude_client.sh`: full Claude Code

```shell
./claude_client.sh
```

Runs `claude --settings claude_client.settings.json`. The settings file only contains the `env` block above, so everything else comes from your own configuration: all built-in tools, plugins, skills, claude.ai connectors and MCP servers. Use it when you want the normal Claude Code experience and mostly work with the cloud models, switching to the local one from `/model` when useful. The full startup context is about 55k tokens, so the first turn on the local model is slow.

### `claude_lean.sh`: lean Claude Code profile

A default interactive Claude Code session sends about 55k tokens before you type anything. Measured on one session, 83 tool schemas account for 45k of it (35 built-in tools plus 48 claude.ai connector tools), the plugin hooks, skill list and CLAUDE.md files for 7k, and the core system prompt for 3k. On a 27B model that first request takes minutes.

```shell
./claude_lean.sh
```

starts Claude Code against the gateway with about 7k tokens of context. It runs:

```shell
claude \
    --settings claude_lean.settings.json \
    --strict-mcp-config --mcp-config claude_lean.mcp.json \
    --tools "Bash,Read,Edit,Write,Grep,Glob" \
    --disable-slash-commands
```

- `claude_lean.settings.json` points at the gateway, adds the local model to `/model`, and disables the claude.ai connectors, bundled skills, auto-memory and plugins. `--settings` adds to `~/.claude/settings.json` rather than replacing it, so the `enabledPlugins` block lists each plugin with `false`. Edit it to match the plugins installed on your machine.
- `claude_lean.mcp.json` is an empty MCP server list, `--strict-mcp-config` makes it the only one used.
- `--tools` keeps six built-in tools. Add more if needed, each one costs 300 to 2,300 tokens of schema.
- `--disable-slash-commands` removes the skill descriptions from the prompt.

The claude.ai login and the cloud models keep working. Extra arguments are passed through to `claude`, for example `./claude_lean.sh --model bonsai-2-27b` to start directly on the local model.

If you only want the biggest saving without changing anything else, add `"disableClaudeAiConnectors": true` to `~/.claude/settings.json`: it removes about 20k tokens on its own.

## Troubleshooting

- `request (N tokens) exceeds the available context size`: the prompt is larger than `-c`. `claude_server.sh` uses 128k, which is enough for Claude Code with many tools enabled. `claude_lean.sh` shrinks the prompt itself.
- `couldn't bind HTTP server socket`: port 8080 is already taken, stop the other process or pass `--port` to the script.
- `401 x-api-key header is required` when calling a Claude model directly with `curl`: expected, the gateway passes requests through and Anthropic needs credentials. Claude Code supplies them itself.

## Further documentation

- [tools/server/README.md](tools/server/README.md): full `llama-server` API reference, including the Anthropic endpoints and `--upstream-url`.
- [docs/build.md](docs/build.md): build options for other backends (CUDA, Vulkan, CPU only).
- Upstream projects: [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp) and [PrismML-Eng/llama.cpp](https://github.com/PrismML-Eng/llama.cpp). This repository keeps their MIT license, see [LICENSE](LICENSE).
