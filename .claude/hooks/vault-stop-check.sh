#!/bin/bash
# vault-stop-check.sh — Stop hook for the Klara vault. The only hook with teeth.
#
# When a decision-shaped event happened and the ticket note still has not been
# touched N turns later, block the stop so the agent actually writes the entry
# instead of receiving a suggestion it is free to drop.
#
# Every fence below is load-bearing. In particular `stop_hook_active` is checked
# FIRST: Claude Code sets it when a Stop hook already caused a continuation, and
# not checking it is the documented way to build an infinite loop.
#
# Deliberately not `set -euo pipefail` — see vault-session-start.sh.

# --- The knob. Turn this first if the nagging grates. -------------------------
NAG_TURN_THRESHOLD=8
# -----------------------------------------------------------------------------

VAULT="${KLARA_VAULT_DIR:-$HOME/Documents/klara-vault}"
STATE_DIR="$HOME/.claude/vault-state"

# stdin can only be read once.
INPUT="$(cat 2>/dev/null)"
[ -n "$INPUT" ] || exit 0

command -v jq >/dev/null 2>&1 || exit 0

# 1. Loop guard, before anything else.
STOP_ACTIVE="$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)"
[ "$STOP_ACTIVE" = "true" ] && exit 0

# 2. Kill switches (part one: the ones that need no ticket).
[ "${KLARA_VAULT_NAG:-1}" = "0" ] && exit 0
[ -e "$STATE_DIR/off" ] && exit 0

# 3. Vault, state file, ticket.
[ -d "$VAULT" ] || exit 0

SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)"
[ -n "$SESSION_ID" ] || exit 0

STATE_FILE="$STATE_DIR/$SESSION_ID.json"
[ -f "$STATE_FILE" ] || exit 0

TICKET="$(jq -r '.ticket // empty' "$STATE_FILE" 2>/dev/null)"
[ -n "$TICKET" ] || exit 0

NOTE="$VAULT/tickets/$TICKET.md"

# 2. Kill switches (part two: per-ticket `nag: off` in the frontmatter).
# Only the leading frontmatter block is inspected, and only the value — the
# template ships `nag: on   # set to `off` to silence`, which must not match.
if [ -f "$NOTE" ]; then
  if awk 'NR==1 && $0!="---"{exit} NR==1{next} /^---[[:space:]]*$/{exit} {print}' \
       "$NOTE" 2>/dev/null \
       | grep -qiE '^nag:[[:space:]]*(off|false|no)[[:space:]]*(#.*)?$'; then
    exit 0
  fi
fi

read_num() { # read_num <file> <jq-path>; echoes an integer, 0 on anything odd
  local v
  v="$(jq -r "$2 // 0" "$1" 2>/dev/null)"
  case "$v" in ''|*[!0-9]*) echo 0 ;; *) echo "$v" ;; esac
}

# 4. Count this completed turn and persist immediately.
TURNS="$(read_num "$STATE_FILE" '.turns')"
TURNS=$((TURNS + 1))
TMP="$STATE_FILE.tmp.$$"
if jq --argjson t "$TURNS" '.turns = $t' "$STATE_FILE" >"$TMP" 2>/dev/null; then
  mv -f "$TMP" "$STATE_FILE" 2>/dev/null
else
  rm -f "$TMP" 2>/dev/null
  exit 0
fi

# 5. Nothing to log.
DIRTY_AT="$(read_num "$STATE_FILE" '.dirty_at')"
[ "$DIRTY_AT" -eq 0 ] && exit 0

# 6. Note already written since the session went dirty — clear the flag.
if [ -f "$NOTE" ]; then
  MTIME="$(stat -f %m "$NOTE" 2>/dev/null || stat -c %Y "$NOTE" 2>/dev/null)"
  case "$MTIME" in ''|*[!0-9]*) MTIME=0 ;; esac
  if [ "$MTIME" -gt "$DIRTY_AT" ]; then
    TMP="$STATE_FILE.tmp.$$"
    if jq '.dirty_at = 0 | .dirty_turn = 0' "$STATE_FILE" >"$TMP" 2>/dev/null; then
      mv -f "$TMP" "$STATE_FILE" 2>/dev/null
    else
      rm -f "$TMP" 2>/dev/null
    fi
    exit 0
  fi
fi

# 7. Not enough has happened yet.
DIRTY_TURN="$(read_num "$STATE_FILE" '.dirty_turn')"
[ $((TURNS - DIRTY_TURN)) -lt "$NAG_TURN_THRESHOLD" ] && exit 0

# 8. Never block twice for the same dirty episode. If the first block did not
# produce a write, downgrade to a silent no-op rather than escalating.
LAST_BLOCK_TURN="$(read_num "$STATE_FILE" '.last_block_turn')"
if [ "$LAST_BLOCK_TURN" -ne 0 ] && [ "$LAST_BLOCK_TURN" -ge "$DIRTY_TURN" ]; then
  exit 0
fi

# 9. Block.
TMP="$STATE_FILE.tmp.$$"
if jq --argjson t "$TURNS" '.last_block_turn = $t' "$STATE_FILE" >"$TMP" 2>/dev/null; then
  mv -f "$TMP" "$STATE_FILE" 2>/dev/null
else
  rm -f "$TMP" 2>/dev/null
  exit 0
fi

jq -n --arg note "$NOTE" --arg key "$TICKET" \
  '{decision:"block",reason:("Vault: work happened on " + $key + " but " + $note + " has not been updated. Append one dated entry (date +%F) under Decisions, Findings, or Log — whichever fits — then stop. A Decisions entry must name the rejected alternative: \"chose X over Y because Z\". Append only; never rewrite an earlier entry. If there is genuinely nothing worth recording, say so and stop.")}' \
  2>/dev/null

exit 0
