#!/bin/bash
# vault-event-nudge.sh — PostToolUse hook for the Klara vault.
#
# Fires on the moments a decision typically crystallizes (a commit, a PR being
# opened or commented on, a Jira transition or comment). Marks the session
# dirty and injects a one-line reminder naming the ticket note.
#
# Non-blocking: context injection only. Silent no-op on every unexpected input.
#
# Deliberately not `set -euo pipefail` — see vault-session-start.sh.

VAULT="${KLARA_VAULT_DIR:-$HOME/Documents/klara-vault}"
STATE_DIR="$HOME/.claude/vault-state"

# stdin can only be read once.
INPUT="$(cat 2>/dev/null)"
[ -n "$INPUT" ] || exit 0

command -v jq >/dev/null 2>&1 || exit 0
[ -d "$VAULT" ] || exit 0

SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)"
[ -n "$SESSION_ID" ] || exit 0

TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
[ -n "$TOOL_NAME" ] || exit 0

# Bash is matched broadly by the settings.json matcher, so filter here to the
# three commands that actually mark a decision. Everything else is noise.
if [ "$TOOL_NAME" = "Bash" ]; then
  CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
  [ -n "$CMD" ] || exit 0
  printf '%s' "$CMD" \
    | grep -qE 'git( +-[^ ]+( +[^ ]+)?)* +commit|gh +pr +(create|comment)' \
    || exit 0
fi
# Any other tool reaching this hook is one of the Jira MCP tools named in the
# matcher; those always count.

STATE_FILE="$STATE_DIR/$SESSION_ID.json"
[ -f "$STATE_FILE" ] || exit 0

TICKET="$(jq -r '.ticket // empty' "$STATE_FILE" 2>/dev/null)"
[ -n "$TICKET" ] || exit 0

NOW="$(date +%s 2>/dev/null)"
[ -n "$NOW" ] || exit 0

DIRTY_AT="$(jq -r '.dirty_at // 0' "$STATE_FILE" 2>/dev/null)"
case "$DIRTY_AT" in ''|*[!0-9]*) DIRTY_AT=0 ;; esac

# Start the countdown at the FIRST crystallizing event, not the last. Resetting
# the clock on every commit would mean a busy session never trips the backstop.
if [ "$DIRTY_AT" -eq 0 ]; then
  TMP="$STATE_FILE.tmp.$$"
  if jq --argjson now "$NOW" \
       '.dirty_at = $now | .dirty_turn = (.turns // 0)' \
       "$STATE_FILE" >"$TMP" 2>/dev/null; then
    mv -f "$TMP" "$STATE_FILE" 2>/dev/null
  else
    rm -f "$TMP" 2>/dev/null
  fi
fi

NOTE="$VAULT/tickets/$TICKET.md"

jq -n --arg note "$NOTE" \
  '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:("Vault: that looked like a decision point. Consider appending a dated entry to " + $note + " (vault skill, `log` procedure) — Decisions must name the rejected alternative.")}}' \
  2>/dev/null

exit 0
