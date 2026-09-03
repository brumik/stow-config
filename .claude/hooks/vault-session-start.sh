#!/bin/bash
# vault-session-start.sh — SessionStart hook for the Klara vault.
#
# Prunes stale per-session state, then (only if the vault exists) tells the
# agent where the vault is and to run the `vault` skill's `pull` procedure.
#
# Failure mode is always a silent no-op. Never errors, never blocks.
#
# Deliberately not `set -euo pipefail`: a hook that aborts on an unset variable
# is a broken hook, and a broken hook here degrades every session.

VAULT="${KLARA_VAULT_DIR:-$HOME/Documents/klara-vault}"
STATE_DIR="$HOME/.claude/vault-state"
PRUNE_DAYS=7

# Drain stdin so the caller never sees EPIPE. We do not need any field from it.
cat >/dev/null 2>&1

mkdir -p "$STATE_DIR" 2>/dev/null

# Prune only session state files. The `off` kill switch is not a *.json and so
# survives, which is the point — a global mute must not expire on its own.
find "$STATE_DIR" -maxdepth 1 -type f -name '*.json' -mtime "+$PRUNE_DAYS" -delete 2>/dev/null

# No vault on this machine: emit nothing at all.
[ -d "$VAULT" ] || exit 0

cat <<EOF
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"Klara vault is available at $VAULT. If this session concerns a ticket, invoke the \`vault\` skill and run its \`pull\` procedure before working."}}
EOF

exit 0
