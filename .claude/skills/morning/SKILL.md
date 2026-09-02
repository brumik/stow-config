---
name: morning
description: Use when the user invokes /morning — reports a digest of actionable GitHub items and assigned Jira tickets. Read-only, no state tracked between runs.
---

# Morning

A read-only digest across GitHub and Jira, scoped to **only what's personally actionable** —
not everything outstanding, not things you're merely waiting on. GitHub notification state
(read/unread, review state) is the only source of truth; nothing is persisted between runs.

Everything below is scripted — run the scripts and paste their output verbatim. Don't
re-derive, re-filter, or re-format their results; that's the whole point of scripting it.

## 1. GitHub — actionable, personal only

```bash
bash .claude/skills/morning/scripts/github.sh actionable
```

Outputs one bullet per item, or `NONE`. Covers exactly three things, each already filtered to
be personal (not team) and human (not bot):

- Assigned directly to you (`reason: assign`).
- Personally requested for review — not just via a team you belong to.
- A human (non-bot) comment on a PR **you authored**.

Deliberately excluded: CI activity, mentions, comments on PRs you don't own, bot comments,
team-only review requests.

## 2. GitHub — your PRs blocked on you

```bash
bash .claude/skills/morning/scripts/github.sh your-prs
```

Outputs one bullet per PR with an outstanding `CHANGES_REQUESTED` review, or `NONE`. Missing
approvals alone is **not** included — that's waiting on someone else, not actionable by you.

## 3. Jira — assigned tickets (current sprint)

```
mcp__atlassian__jira_search(
  jql: "assignee = currentUser() AND statusCategory != Done AND sprint in openSprints() ORDER BY updated DESC",
  fields: "key,summary,status"
)
```

Use `statusCategory != Done`, not `resolution = Unresolved` — some tickets carry a Done-category
status (Resolved/Closed) with an empty `resolution` field, which slips past a resolution filter.

Pipe the raw tool result into:

```bash
echo '<tool result json>' | bash .claude/skills/morning/scripts/format-jira.sh
```

Outputs one markdown link bullet per issue, or `NONE`.

## 4. Jira — mentions

```
mcp__atlassian__jira_search(
  jql: "mentions = currentUser() AND updated >= -7d ORDER BY updated DESC",
  fields: "key,summary,status"
)
```

Same `format-jira.sh` formatting. Capped to 7 days because Jira has no unread-mentions
concept — without the cap this would keep re-surfacing the same old mentions every run.

## Output

One message, four headed sections (GitHub: Actionable / GitHub: Blocked on You / Jira:
Assigned / Jira: Mentions). Omit a section entirely if its script/query returned `NONE` —
don't print "none found" noise.
