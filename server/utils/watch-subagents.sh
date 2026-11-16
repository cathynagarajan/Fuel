#!/usr/bin/env bash
# ==============================================================================
#  ANTIGRAVITY DELEGATED SUBAGENTS LIVE MONITOR (watch-subagents)
#  Streams ONLY delegated subagent conversations ([SUBAGENT <id>]),
#  invoke_subagent spawns, and inter-agent send_message handoffs.
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/watch-agent-activity.sh" --subagents-only "$@"
