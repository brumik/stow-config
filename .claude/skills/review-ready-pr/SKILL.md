---
name: review-ready-pr
description: Use when opening a PR or making one review-ready on the Klara backend repos (klara-backend-voicemail, -ehr-integration, -messaging, etc.) — formats the title and body to the team convention and clears working/progress comments left during implementation.
---

# Review-ready PR format

The convention for a PR that's ready for a human reviewer. Apply it when opening a PR, or when
asked to "make it review-ready" / "clean up the PR".

Core principle: **the diff already shows *what* changed — don't restate it.** The body is only
for things the diff can't tell the reviewer: which ticket, what's non-obvious, and what you
verified. Keep it short and high-signal.

## Title

```
[KLARA-NNNNN] Short imperative description
```

- One ticket key in brackets — the work item the PR **resolves/closes**. If the PR spans an
  epic + a story, lead with the closeable **story**, not the epic. If genuinely unsure which of
  several tickets heads the title, ask the user (it sets the convention).
- Description is a concise summary, with optional parenthetical scope hints:
  `(core-client 7.6 / faraday 2 / omniauth 2)`.

## Body

Two metadata lines, then two fixed subsections. Nothing else.

```markdown
- **Ticket:** [KLARA-NNNNN](https://modmedrnd.atlassian.net/browse/KLARA-NNNNN)
- **PRs:** Supersedes #1234, #1235

## Clarifications

<Bullets for code-level facts the reviewer can't infer from the diff itself — each one points
at the code and explains a *decision*, not the story of how you worked. Good candidates: a
non-obvious workaround and why it was necessary; why one implementation was chosen over the
obvious alternative; a non-local consequence of a change; why a seemingly-unrelated file had to
change; why a specific version was picked; why something needed NO change; an API migration's
gotcha.

NOT process or history: how you regenerated a lockfile, which merge conflicts you resolved and
how, local-environment struggles, "I rebased then …". The reviewer reviews the resulting code,
not your workflow — that narration is noise here. If a process step changes what to *trust* in
the diff (e.g. a lockfile was regenerated in-container, a test can't run locally), state the
*outcome* under **Tested with**, not the play-by-play here.>

## Tested with

- **Dock e2e** (`<svc>` + `<svc>-test` rebuilt): Rubocop N offenses; RSpec X examples, Y failures, Z pending.
- **CI:** which jobs pass; note any that skip by design.
- **<other>:** Snyk / manual boot / etc., and anything left to confirm externally.
```

Rules that matter (these are the corrections the convention was tuned on):

- **No summary paragraph or change/diff table between the metadata and Clarifications.** If the
  diff makes it clear, it doesn't belong in the body.
- **Clarifications are about the code, not the process.** Each bullet should help someone
  *reading the diff* — a non-obvious workaround, a decision, a non-local effect. The story of
  how you got there (rebases, conflict resolution, lockfile regen dances, env fights) is not a
  clarification; drop it or, if it changes what to trust in the diff, fold the outcome into
  **Tested with**.
- **`PRs:` lists only actually-opened PRs** — just the links, no per-PR explanation. Drop it
  entirely if there are none. Non-PR companion changes (a tweak in another repo, a local-only
  dependency) don't belong in the body at all.
- **No epic line** unless the user asks for it.
- Relationship verb before the PR list — the precise one: `Supersedes` (this replaces/closes
  them), `Requires` (must merge first), `Stacked on` (based on another branch).

## Clear working comments

Progress notes you posted on the PR while implementing (Dock e2e results, "CI green", "also
closes X", debugging updates) are scaffolding — **fold their durable content into the body,
then delete the comments** so the reviewer opens a clean PR. Authorized cleanup of *your own*
comments only; never delete anyone else's.

```bash
# list your PR-level comments (note issuecomment-<ID> in each url)
gh pr view <num> --json comments --jq '.comments[] | {author: .author.login, url: .url}'
gh api -X DELETE repos/<owner>/<repo>/issues/comments/<ID>
```

## Setting the title/body

- Write the body to a temp file and use `--body-file` rather than inlining — markdown tables
  and backticks survive intact:
  ```bash
  gh pr edit <num> --title "[KLARA-NNNNN] …" --body-file /tmp/pr-body.md
  ```
- **If `gh pr edit` fails on auth**, the cause is the token, not the command. The mutation
  resolves the org-owned repo's `login` field, gated by *both* the `read:org` scope *and* SAML
  SSO authorization for the org — symptoms are `requires read:org scope` or `Resource protected
  by organization SAML enforcement`. Fix the token rather than working around it:
  `gh auth refresh -h github.com -s read:org` for the scope, and authorize the PAT for the org
  via Settings → Developer settings → PAT → **Configure SSO** (or the SSO link the error prints).
  The REST `gh api -X PATCH repos/<owner>/<repo>/pulls/<num> -f title=… -f body="$(cat …)"`
  sidesteps the org-field resolution if you're ever stuck with a token you can't fix.
