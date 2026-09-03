---
name: implement-and-pr
description: Use when the user hands you an implementation task and wants the full loop from
  design through review — plan it in plan mode, get their explicit approval, then implement,
  test, and open a new branch + commit + draft PR and hand back the link. Never skip the
  approval gate; never open more than a draft PR.
---

# Implement and PR

End-to-end workflow for turning an approved plan into a draft PR, without skipping the approval
gate or accidentally publishing more than a draft. Use it when the user hands you an
implementation task and wants the full loop: plan → approval → code → tests → draft PR link.

## 1. Plan first — don't skip straight to code

Enter plan mode (`EnterPlanMode`) and explore/design there, even if the change feels
straightforward. This is the gate that prevents wasted implementation work on a plan the user
would have redirected.

## 2. Get explicit approval — non-negotiable

Call `ExitPlanMode` and wait for the user's approval. Do **not** start editing, running
non-readonly commands, or making any change before it comes back approved. If the user asks for
changes, revise and exit plan mode again — don't treat a first pass as good enough.

## 3. The approved plan is already written down

Plan mode writes the final plan to `~/.claude/plans/<slug>.md` as part of exiting — that file is
the durable record; you don't need to re-save it elsewhere.

If the session has accumulated a lot of exploration context and you expect a long implementation
+ test + PR tail, consider `/compact` now — the plan file survives compaction, so nothing is
lost, and the rest of the workflow runs cheaper.

## 4. Implement, test, branch/commit/draft PR — all inline

No subagent dispatch in this step. Follow the approved plan; don't improvise scope beyond it
without going back for approval.

Run the relevant tests directly and fix failures. The one exception is nested, not a dispatch of
its own: if the Dock environment breaks mid-test, invoke the `repairing-dock-environment` skill
(it delegates to its own environment-only subagent, waits, and reports the fix), then resume
testing inline — don't duplicate that skill's logic here, just point to it.

Once tests pass:
- If this task already has a branch of its own (e.g. you're resuming or iterating on work
  already in flight), keep committing to it — don't create a new one just for the sake of it.
  Otherwise, create a new branch; never commit the implementation directly on `main`/the
  branch you started on.
- Commit with a message describing why, not what (the diff already shows what).
- Push and open the PR **as a draft** (`gh pr create --draft`), or push further commits to the
  existing draft PR if one's already open. A draft is the deliverable here — don't promote it
  to ready-for-review or ping reviewers; that's a separate, user-prompted step (see
  `review-ready-pr` for formatting it when the user asks to make it review-ready).

## 5. Report back

The result is the draft PR link — hand it back to the user as the final output of this workflow,
plus a note of any environment fixes `repairing-dock-environment` made along the way (it already
requires you to surface those). Nothing further (merging, review-ready formatting, Jira
transitions) happens unless asked.

## Notes

- This workflow assumes an implementation task, not just research — if the ask is exploratory,
  don't force it through plan mode's approval gate.
- If the task started from a Jira ticket, pull ticket context first (see the `vault` skill)
  before entering plan mode — plan quality depends on knowing what "done" means.
