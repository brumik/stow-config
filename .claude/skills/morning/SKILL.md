---
name: morning
description: Use when the user invokes /morning — reports a digest of the vault scratchpad, actionable GitHub items, and assigned Jira tickets. Read-only, no state tracked between runs.
---

# Morning

A read-only digest across the vault scratchpad, GitHub, and Jira, scoped to **only what's
personally actionable** — not everything outstanding, not things you're merely waiting on.
GitHub notification state (read/unread, review state) is the only source of truth; nothing
is persisted between runs.

Sections 2–5 are scripted — run the scripts and paste their output verbatim. Don't
re-derive, re-filter, or re-format their results; that's the whole point of scripting it.
Section 1 is the exception: it's freeform text that only you can read.

## 1. Scratchpad

```bash
cat ~/Documents/klara-vault/SCRATCH.md 2>/dev/null
```

The user's pad. **Deliberately unstructured** — no frontmatter, no headings, no format at
all. It may be bullets, prose, a bare URL, or a half-sentence. Do not expect a shape, do
not impose one, and never parse it.

It goes first because the pad holds the only items nothing else tracks — no ticket, no PR,
no notification will ever surface them.

- **Empty file, missing file, or no vault → omit the section.** Say nothing about it.
- Otherwise reproduce everything in it. Grouping or tightening line breaks for readability
  is fine; **dropping, merging, summarising, or rewording an item is not.** A line you
  can't interpret still gets printed — you are not the judge of what the user meant.
- **Read-only here.** Do not write to the pad, tick anything off, or offer to drain it.
  Draining is `hygiene.md`, and only when the user asks for it by name.

## 2. GitHub — actionable, personal only

```bash
bash ~/.claude/skills/morning/scripts/github.sh actionable
```

Outputs one bullet per item, or `NONE`. Covers exactly three things, each already filtered to
be personal (not team) and human (not bot):

- Assigned directly to you (`reason: assign`).
- Personally requested for review — not just via a team you belong to.
- A human (non-bot) comment on a PR **you authored**.

Deliberately excluded: CI activity, mentions, comments on PRs you don't own, bot comments,
team-only review requests.

## 3. GitHub — your PRs blocked on you

```bash
bash ~/.claude/skills/morning/scripts/github.sh your-prs
```

Outputs one bullet per PR with an outstanding `CHANGES_REQUESTED` review, or `NONE`. Missing
approvals alone is **not** included — that's waiting on someone else, not actionable by you.

## 4. Jira — assigned tickets (current sprint)

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
echo '<tool result json>' | bash ~/.claude/skills/morning/scripts/format-jira.sh
```

Outputs one markdown link bullet per issue, or `NONE`.

**Don't retype the tool result inline in the `echo` command.** Copying multi-line JSON by
hand into a quoted shell string is exactly how this breaks — a real newline lands inside
what has to be a JSON-encoded string, and `jq` fails on the unescaped control character.
Instead, write the tool result byte-for-byte to a temp file with the Write tool, then feed
the script from that file:

```bash
bash ~/.claude/skills/morning/scripts/format-jira.sh < /tmp/jira_assigned.json
```

**Write the raw tool result verbatim — the `{"result": "<json-string>"}` envelope, not the
parsed object inside it.** The `jira_search` MCP tool result is an object with one key,
`result`, whose value is itself a JSON-encoded *string* (you'll see escaped `\"` and `\n`
inside it). The script's first line is `.result | fromjson` — it does the unwrapping
itself. A recurring mistake is to "clean up" the tool result first — pulling out just the
inner `{"total":..., "issues":[...]}` and writing that instead. That breaks `fromjson`
with `null (null) only strings can be parsed`, because there's no `.result` string to
parse. Write the tool result byte-for-byte, envelope included, with nothing extracted or
reformatted.

## 5. Jira — mentions

```
mcp__atlassian__jira_search(
  jql: "mentions = currentUser() AND updated >= -7d ORDER BY updated DESC",
  fields: "key,summary,status"
)
```

Same `format-jira.sh` formatting. Capped to 7 days because Jira has no unread-mentions
concept — without the cap this would keep re-surfacing the same old mentions every run.

## Output

One message, five headed sections in this order (Scratchpad / GitHub: Actionable / GitHub:
Blocked on You / Jira: Assigned / Jira: Mentions). Omit a section entirely when it's empty
— `NONE` from a script, or nothing in the pad. Don't print "none found" noise.

**Number every item with one running sequence across the whole message** — item 1 is the
first bullet of the first non-empty section, and numbering keeps climbing across section
boundaries without resetting. This is so the user can point at anything ("start 3", "move 5
to code review") by number alone instead of repeating text back. Don't number section
headers, only the individual bullets underneath them.
