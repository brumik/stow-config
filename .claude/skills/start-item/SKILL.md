---
name: start-item
description: Use when the user asks to start working on a specific item — usually one surfaced by /morning — identified by a Jira key (e.g. KLARA-1234) or a GitHub PR/issue. Opens a new herdr workspace, cds into the relevant repo, launches a claude session there, and seeds it with a first message telling it to pull its own context. Runs in the background; does not change focus.
---

# Start item

Bootstraps a fresh Claude session for one piece of work, without disturbing the current
session or fetching context yourself — the new session pulls its own. Do this inline —
no subagent dispatch. It's 2-3 tool calls; delegating it burns far more tokens on fixed
agent overhead than it could ever save from your context.

## 1. Resolve a repo path — no lookups

- **GitHub PR/issue** (URL or `owner/repo#123`): the repo name is right there in it. Use
  `/Users/levente.berky/Documents/<repo-name>` if that directory exists.
- **Jira key, or anything else unclear**: don't look anything up (no dev-info call, no
  API round trip). There's no way to know the repo from the key alone — default straight to
  `/Users/levente.berky/Documents`.

Always pass the fully resolved **absolute** path, never a literal `~` — it doesn't tilde-expand
once it's inside a quoted subprocess argument.

## 2. Draft the first message

Don't pull the ticket/PR content — that's the new session's own job (the `vault` skill, which
it invokes itself). Just tell it what to work on:

> Start working on `<item-key>` (`<link, if any>`). Use the `vault` skill to pull your own
> context on it first, then proceed.

## 3. Create the session — fully scripted

```bash
bash ~/.claude/skills/start-item/scripts/create-session.sh "<resolved_cwd>" "<item-key>" "<drafted message>"
```

Handles workspace creation, agent name sanitization, `agent start` (retries briefly if the pane
isn't an available shell yet), and `agent prompt`. Prints `{agent, pane, workspace, cwd}` on
success; runs in the background (`--no-focus`, no `--wait`) so the current session is untouched.

Report that result to the user verbatim-ish (which workspace/label it landed in) — don't
re-derive it.

## Notes

- If `cwd` is `/Users/levente.berky/Documents` (the fallback), say so explicitly — the new
  session will need to navigate to the right repo itself.
- Don't close, focus, or otherwise touch the new pane after the script succeeds; this skill's
  job ends at submission.
