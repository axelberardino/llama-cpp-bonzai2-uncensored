#!/usr/bin/env bash
# Start Claude Code with its full default context (all tools, plugins, skills, connectors, MCP servers)
# pointed at the local gateway started by claude_server.sh. Your ~/.claude/settings.json is left untouched.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

exec claude --settings "$HERE/claude_client.settings.json" "$@"
