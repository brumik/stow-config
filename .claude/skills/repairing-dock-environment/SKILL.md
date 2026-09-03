---
name: repairing-dock-environment
description: Use when the Dock local dev environment breaks during a coding or testing task — Docker build failures, "Gemfile.lock/package-lock out of sync", a container unhealthy or stuck restarting, "database not found"/empty DB/ActiveRecord::PendingMigrationError, a dead overmind process (rails/sidekiq/consumers), or mcp__dock__* tools returning infrastructure errors instead of your code's results. Keeps your main task context clean.
---

# Repairing the Dock Environment

## Overview

When the **Dock** local dev environment (the Klara platform, driven by `mcp__dock__*`
tools) breaks *while you are doing something else*, repairing it inline floods your
working context with build logs, job polling, and `docker` diagnostics — and derails the
task you were actually asked to do.

**Core rule:** environment breakage is *not* your task. Delegate the repair to a
**fresh-context subagent**, wait for it, resume your task, and **report every fix to the
user at the end.** Always — even when the fix looks like one command.

**REQUIRED BACKGROUND:** the `dock` skill (how to drive `mcp__dock__*`; `dock_help` is the
live source of truth; mutating ops are async). **Related:** `superpowers:dispatching-parallel-agents`.

**Dock is disposable, not prod.** It's a personal, per-developer environment.
`dock_reload` is non-destructive and cheap — reach for it freely, starting with a rebuild
before deeper diagnosis. `dock_seed` wipes the target DB, which is fine unless someone has
manually curated test data worth keeping — flag it in your report either way. The real
anti-pattern is hand-patching data via `dock_shell`/`dock_psql` as a workaround: the patch
vanishes on the next rebuild and helps no one else. If a fix keeps needing to be reapplied,
that's a signal to fix the seed script/migration/Dockerfile instead of patching around it —
see `dock_help(topic='debugging')` for the full guidance and current symptom→fix list.

## Is this actually an environment break? (don't offload real debugging)

| Delegate to a repair subagent (ENVIRONMENT) | Handle it yourself (YOUR CODE) |
|---|---|
| Docker build fails; lock file out of sync | A test asserts wrong values on logic you changed |
| Container won't start / unhealthy / restart-loops | Your new migration is itself malformed |
| DB not seeded / empty / `PendingMigrationError` on a schema you didn't touch | Lint flags *your* diff |
| Overmind process (rails/sidekiq/consumers) crashed | A `NoMethodError`/bug in the code you just wrote |
| `mcp__dock__*` returns infra errors, not your results | A feature behaves wrong but the stack is healthy |

Rule of thumb: **was it working before, and broke due to a checkout/pull/migration/stale
container/missing seed?** → environment → delegate. **Is the stack healthy and your code
is the thing under test?** → debug it yourself.

## The workflow

1. **Note where you are** in the real task (the failing command, what you'd do next) so
   you can resume cleanly.
2. **Dispatch a repair subagent** with the template below — `subagent_type: general-purpose`
   (it needs the mutating `mcp__dock__*` tools), **synchronously** (your task is blocked on
   the env, so wait for the result; do not run it in the background and move on).
3. **Read its summary.** If it reports it needs a destructive action or a user decision,
   surface that to the user before doing anything else.
4. **Resume your task** from step 1.
5. **Record the fix** in a running list (one line per repair).
6. **At the end of the task**, give the user an `## Environment fixes during this task`
   section: what broke, what the subagent did, and anything needing follow-up.

## Subagent dispatch template

```
You are a Dock environment repair agent. The Klara local dev environment (driven by the
mcp__dock__* tools) has broken while the main session was working on an UNRELATED coding
task. Your ONLY job: get the environment healthy again. Do not read, write, or reason
about feature/application code.

What failed (verbatim):
  <command that failed, e.g. dock_test(service='core', ...)>
  <exact error output>

How to work:
- Use the `dock` skill and dock_help(topic=...) as the source of truth — it's the living
  doc, kept current in the Dock MCP itself. Read service/process names from the tool
  enums — never guess. Call dock_help(topic='debugging') for the current rebuild-first
  heuristic and symptom→fix list; don't rely on a stale copy from memory.
- Try the obvious fix first: usually `dock_reload(service)` (match `<service>-test` if the
  failure came from dock_test), or `dock_lock_update(service)` → `dock_reload(service)` for
  a lock-file error. It's non-destructive and clears most cases cheaply.
- If that doesn't resolve it, diagnose with read-only tools: dock_doctor(),
  dock_status(service), dock_logs(service, process), dock_db_status() — then apply the
  targeted fix from dock_help(topic='debugging'). Mutating ops are async — poll
  dock_job_status(job_id=...) until done; a job is fixed only when returncode == 0.
- VERIFY before claiming success: confirm the ENVIRONMENT is healthy again with the
  cheapest sufficient check — the build now completes, dock_status is green, or
  dock_doctor/dock_db_status passes. You need not re-run the user's full test suite (that
  belongs to the main session on resume); just prove the infrastructure failure is gone.

Hard constraints:
- DO NOT run dock_stop, `just stop-and-clean`, or anything that removes volumes/wipes
  ALL data. If you believe a full destructive reset is the only fix, STOP and report that
  instead — this is different from a normal single-service `dock_seed`.
- `dock_seed` resets one service's DB and is a normal, expected fix (not a last resort) —
  use it whenever the runbook calls for it. Always call it out in your report so whoever
  resumes knows their data changed, but don't withhold it out of excess caution.
- Do NOT paper over a problem by hand-patching rows/config via `dock_shell`/`dock_psql`
  instead of using the real fix (reload/reseed/lock-update). A hand-patch vanishes on the
  next rebuild and isn't a repair — it's technical debt with your name missing from it.

Return ONLY this summary (no preamble):
- What broke (symptom + your diagnosis of the root cause)
- Steps taken (each command + its job result)
- Verification (what you re-ran, and that it passed)
- Data impact (did anything get reset/reseeded?)
- Needs user attention (destructive action required, ambiguous cause, or "none")
```

## Symptom → fix guidance

Lives in `dock_help(topic='debugging')` now, not here — it's maintained alongside the Dock
MCP itself (`klara-qa-dock/appdata/dock-mcp/help.py`), so it stays current as services and
gotchas change. Have the subagent call it rather than working from a table that can go
stale in this file. It covers: lock-file-out-of-sync, migration errors, unhealthy/
restart-looping containers, dead overmind processes, stale `*-test` containers, missing
prerequisites, and the rebuild-first heuristic.

One thing worth restating here because it's easy to get backwards: **match the reload
target to the path that failed** — a failure surfaced by `dock_test` lives in the
`*-test` container, so reload `<service>-test`, not the app container, or the retry hits
the same stale build.

## Red flags — you are about to violate the rule

- "I'll just fix the env quickly inline, then get back to the task" → **No. Delegate.**
  Inline repair pollutes your context; that is the whole problem.
- "It's basically a code issue" when the stack itself is broken → re-read the decision
  table above.
- "The fix was one command, no need to mention it" → **report it anyway** in the
  end-of-task summary. The user must know their environment changed.
- "I'll just tweak this row/config directly instead of reseeding" → that's a hand-patch,
  not a fix; it disappears on the next rebuild. Use the real fix and flag any data reset.
- "Job call returned, so it worked" → not until `returncode == 0` and you re-verified.

## Common mistakes

- Running the repair in the background and continuing the task → the task depends on a
  healthy env; dispatch synchronously and wait.
- Letting the subagent touch feature code → its scope is the environment only.
- Forgetting the end-of-task summary → the user loses visibility into what changed.
