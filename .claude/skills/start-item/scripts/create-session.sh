#!/usr/bin/env bash
# Fully scripted session bootstrap for the start-item skill — no LLM judgment involved.
# Usage: create-session.sh <cwd> <item-key> <message>
#   cwd       resolved local repo path (or ~/Documents fallback)
#   item-key  human label, e.g. KLARA-1234 or repo#123 (sanitized into the agent name)
#   message   first message to send into the new session
set -euo pipefail

cwd="$1"
item_key="$2"
message="$3"

# A literal leading "~" doesn't tilde-expand once it's inside a quoted arg passed to a
# subprocess — normalize it here so callers can't land in $HOME by accident.
case "$cwd" in
  "~") cwd="$HOME" ;;
  "~/"*) cwd="$HOME/${cwd#\~/}" ;;
esac

agent_name="$(printf '%s' "$item_key" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_-]/-/g' | cut -c1-32)"
case "$agent_name" in
  [a-z]*) ;;
  *) agent_name="i-${agent_name}" ;;
esac
agent_name="$(printf '%s' "$agent_name" | cut -c1-32)"

ws_json="$(herdr workspace create --cwd "$cwd" --label "$item_key" --no-focus)"
pane_id="$(printf '%s' "$ws_json" | jq -r '.result.root_pane.pane_id')"
workspace_id="$(printf '%s' "$ws_json" | jq -r '.result.workspace.workspace_id')"


# The pane isn't an "available shell" the instant workspace create returns — the shell
# process is still spawning. Retry briefly instead of failing on agent_pane_busy.
for attempt in 1 2 3 4 5; do
  if herdr agent start "$agent_name" --kind claude --pane "$pane_id" >/dev/null 2>/tmp/start-item-agent-start.err; then
    break
  fi
  if [ "$attempt" = 5 ]; then
    cat /tmp/start-item-agent-start.err >&2
    exit 1
  fi
  sleep 1
done

herdr agent prompt "$agent_name" "$message" >/dev/null

jq -n \
  --arg agent "$agent_name" \
  --arg pane "$pane_id" \
  --arg workspace "$workspace_id" \
  --arg cwd "$cwd" \
  '{agent: $agent, pane: $pane, workspace: $workspace, cwd: $cwd}'
