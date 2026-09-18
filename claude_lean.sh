#!/usr/bin/env bash
# Start Claude Code with a minimal context (about 7k tokens instead of 55k) for use with the local gateway.
# Disables claude.ai connectors, plugins, bundled skills, auto-memory and all MCP servers, keeps 6 built-in tools.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

exec claude \
    --settings "$HERE/claude_lean.settings.json" \
    --strict-mcp-config --mcp-config "$HERE/claude_lean.mcp.json" \
    --tools "Bash,Read,Edit,Write,Grep,Glob" \
    --disable-slash-commands \
    "$@"
