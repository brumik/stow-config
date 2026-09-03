---
name: start-item
description: Use when the user asks to start working on a specific item — usually one surfaced by /morning — identified by a Jira key (e.g. KLARA-1234) or a GitHub PR/issue. Opens a new herdr tab in the current workspace, cds into the relevant repo, launches a claude session there, and seeds it with a first message telling it to pull its own context. Runs in the background; does not change focus.
---

# Start item

Bootstraps a fresh Claude session for one piece of work, without disturbing the current
session or fetching context yourself — the new session pulls its own. Do this inline —
no subagent dispatch. It's 2-3 tool calls; delegating it burns far more tokens on fixed
agent overhead than it could ever save from your context.

## 0. Is this a clean reference, or a freeform note?

A **clean reference** is an exact Jira key or GitHub PR/issue that stands for the whole
task — the ticket title/description already *is* the task. A **freeform note** is anything
else the item came from, most often a scratchpad line: it may *mention* a Jira key (an epic,
a related ticket, a "see also"), but that key is not the task — the note's own text is.

Telling these apart matters because a freeform note has no vault entry and no ticket body
behind it. If you hand the new session just the key it found, it will pull that ticket's own
context and start working on *that ticket*, silently losing whatever the note actually asked
for (e.g. "in this epic, create a new ticket for X" — X is the task, the epic key is just
where it lives). There is nowhere else that meaning is recoverable from — the note is the
only copy.

If it's a freeform note, carry its **full original text verbatim** into the drafted message
in step 2 — don't compress it down to a key, a paraphrase, or "the acr_values thing."

## 1. Resolve a repo path — no lookups

- **GitHub PR/issue** (URL or `owner/repo#123`): the repo name is right there in it. Use
  `/Users/levente.berky/Documents/<repo-name>` if that directory exists.
- **Jira key, or anything else unclear**: don't look anything up (no dev-info call, no
  API round trip). There's no way to know the repo from the key alone — default straight to
  `/Users/levente.berky/Documents`.

Always pass the fully resolved **absolute** path, never a literal `~` — it doesn't tilde-expand
once it's inside a quoted subprocess argument.

## 2. Draft the first message

For a **clean reference**: don't pull the ticket/PR content — that's the new session's own
job (the `vault` skill, which it invokes itself). Just tell it what to work on:

> Start working on `<item-key>` (`<link, if any>`). Use the `vault` skill to pull your own
> context on it first, then proceed.

For a **freeform note**: the note *is* the context — there's no vault entry to pull it back
from, so losing it here loses it for good. Quote it in full, then add any key it mentioned as
a reference, not the target:

> Start working on this: `<full original note text, verbatim>`. Note: `<key>` mentioned in it
> is a reference/epic, not necessarily the item itself — still use the `vault` skill to pull
> context on it, but the task is what the note above says.

## 3. Create the session — fully scripted

```bash
bash ~/.claude/skills/start-item/scripts/create-session.sh "<resolved_cwd>" "<item-key>" "<drafted message>"
```

Handles tab creation (a new tab in the *current* workspace, not a new workspace — falls back
to a new workspace only if `$HERDR_WORKSPACE_ID` is unset), agent name sanitization, `agent
start` (retries briefly if the pane isn't an available shell yet, starts the new session in
`--permission-mode plan` so it can explore/pull context without a permission prompt per
read), and `agent prompt`. Prints `{agent, pane, workspace, cwd}` on success; runs in the
background (`--no-focus`, no `--wait`) so the current session is untouched.

`<item-key>` here is just a short label (sanitized, cut to 32 chars) — for a freeform note,
don't pass the whole note as this argument, invent a short slug for it instead (e.g.
`acr-values-2`). The full note text belongs only in the drafted `<message>` argument.

Report that result to the user verbatim-ish (which workspace/label it landed in) — don't
re-derive it.

## Notes

- If `cwd` is `/Users/levente.berky/Documents` (the fallback), say so explicitly — the new
  session will need to navigate to the right repo itself.
- Don't close, focus, or otherwise touch the new pane after the script succeeds; this skill's
  job ends at submission.
