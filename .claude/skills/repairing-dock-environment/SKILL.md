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
- Use the `dock` skill and dock_help(topic=...) as the source of truth. Read service/
  process names from the tool enums — never guess.
- Diagnose with read-only tools first: dock_doctor(), dock_status(service),
  dock_logs(service, process), dock_db_status().
- Apply the least-destructive fix (see the runbook). Mutating ops are async — poll
  dock_job_status(job_id=...) until done; a job is fixed only when returncode == 0.
- VERIFY before claiming success: confirm the ENVIRONMENT is healthy again with the
  cheapest sufficient check — the build now completes, dock_status is green, or
  dock_doctor/dock_db_status passes. You need not re-run the user's full test suite (that
  belongs to the main session on resume); just prove the infrastructure failure is gone.

Hard constraints:
- DO NOT run dock_stop, `just stop-and-clean`, or anything that removes volumes/wipes
  data. If you believe a destructive reset is the only fix, STOP and report that instead.
- dock_seed RESETS a database (drops + reseeds) — only seed when the DB is genuinely
  empty or a migration requires it, and call it out in your report.

Return ONLY this summary (no preamble):
- What broke (symptom + your diagnosis of the root cause)
- Steps taken (each command + its job result)
- Verification (what you re-ran, and that it passed)
- Data impact (did anything get reset/reseeded?)
- Needs user attention (destructive action required, ambiguous cause, or "none")
```

## Symptom → fix runbook (give this context to the subagent)

| Symptom | First check | Fix |
|---|---|---|
| "lock file out of sync" (Gemfile.lock / package-lock / go.sum) | build error text | `dock_lock_update(service)` → `dock_reload(service)` (or `<service>-test`) |
| Build fails (bundle/npm/go) | `dock_logs(service)`, job output | check `.env` `GITHUB_TOKEN`/`ROOT_DIR` → `dock_lock_update` → `dock_reload` |
| DB not seeded / "database not found" / empty | `dock_db_status()` | `dock_seed(service)` or `dock_seed('all')` |
| `ActiveRecord::PendingMigrationError` (schema you didn't change) | rails logs | `dock_reload(service)`, then `dock_seed(service)` |
| Container unhealthy / won't start | `dock_status(service)`, `dock_logs(service)` | `dock_reload(service)`; if a dependency isn't ready, wait and re-check |
| Overmind process dead (rails/sidekiq/consumers) | `dock_status(service)` | `dock_restart(service, process)` |
| Missing prerequisite (.env, repo, brew tool) | `dock_doctor()` | follow its recommendations |
| Tests can't find the `*-test` container | — | `dock_reload(service + '-test')` then retry |
| Catastrophic / corrupt volumes | — | **STOP — ask the user** before any `stop-and-clean` → `up` → `seed all` |

> **Match the reload target to the path that failed:** a failure surfaced by `dock_test`
> lives in the `*-test` container — reload `<service>-test`, not the app container, or the
> retry hits the same stale build.

## Red flags — you are about to violate the rule

- "I'll just fix the env quickly inline, then get back to the task" → **No. Delegate.**
  Inline repair pollutes your context; that is the whole problem.
- "It's basically a code issue" when the stack itself is broken → re-read the decision
  table above.
- "The fix was one command, no need to mention it" → **report it anyway** in the
  end-of-task summary. The user must know their environment changed.
- "I'll seed to be safe" → seeding wipes dev data; only the subagent seeds, only when
  warranted, and it must flag it.
- "Job call returned, so it worked" → not until `returncode == 0` and you re-verified.

## Common mistakes

- Running the repair in the background and continuing the task → the task depends on a
  healthy env; dispatch synchronously and wait.
- Letting the subagent touch feature code → its scope is the environment only.
- Forgetting the end-of-task summary → the user loses visibility into what changed.
