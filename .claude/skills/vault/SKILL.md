---
name: vault
description: Use when starting work on a Jira ticket or being handed a ticket key, when intel arrives out of band (Slack thread, email, a call), when a decision gets made or superseded, or when the user asks what's already known about a ticket. Dispatches to the local knowledge vault, which holds the per-ticket decision ledger and promoted knowledge notes.
---

# Vault

A private markdown repo at **`/Users/levente.berky/Documents/klara-vault`** holding a
per-ticket, append-only decision ledger plus promoted knowledge notes. It records what Jira
does not: why the work exists, what was chosen *over what*, and intel that arrived out of band.

This skill is **dispatch only**. It holds no ticket content — this repo is public and the vault
is not. Everything you need is in the vault itself.

## If the vault directory does not exist

```bash
[ -d /Users/levente.berky/Documents/klara-vault ] && echo present || echo absent
```

**Absent → say so once, in one short line, and continue the task normally.** Do not retry, do
not ask the user to create it, do not mention it again for the rest of the session, and do not
let it change how you do the actual work. A machine without the vault should produce an agent
that is merely uninformed, not one that is confused or stuck.

## Otherwise: read the README and pick a procedure

`README.md` at the vault root is the dispatch table and the only file you must read to orient
yourself. It points at five procedures in `procedures/`. Read the one that matches, then follow
it point by point — don't improvise from the one-liners below.

| Procedure | Run it when |
|---|---|
| `pull.md` | Before touching a ticket — the first thing you do on any ticket work. |
| `intake.md` | The ticket has never been worked before and has no note yet. |
| `log.md` | A decision, finding, or event needs recording. The one you run most. |
| `capture.md` | Intel arrived mid-session (Slack, email, a call) — get it in verbatim, fast. |
| `hygiene.md` | On demand only, when the user asks. Never on a schedule. |

## Two invariants — hold these even before you've read a procedure

- **Get the date by running `date +%F`.** Never infer it, never carry one forward from earlier
  in the session, never trust the date injected at session start. Long sessions cross midnight,
  and a ledger with wrong dates is worse than no ledger because it still reads as authoritative.
- **Entries are append-only.** Add; never rewrite an earlier entry to match present
  understanding. A superseded decision gets a *new* dated entry saying it was superseded and
  why. Rewriting history destroys the only thing the ledger is for.
