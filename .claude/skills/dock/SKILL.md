---
name: dock
description: Use when working on the Klara platform locally — running, seeding, testing, linting, or debugging Dock services, or whenever using the mcp__dock__* tools. Explains how to drive the Dock dev environment correctly and where to find always-current details.
---

# Dock

The Klara platform runs locally via the **Dock MCP** (`mcp__dock__*` tools). This is a thin
operating manual — it deliberately copies no service lists, command tables, or topic docs,
because those live in the MCP and would go stale here.

## Sources of truth (always current — consult these, don't trust memory)

- **Tool schemas** — the `service` / `process` enums on each `mcp__dock__*` tool are the
  authoritative list of valid names. Never guess a service or process name; read the enum.
- **`dock_help(topic=...)`** — living docs maintained alongside the MCP. Topics: `services`,
  `urls`, `credentials`, `workflows`, `debugging`, `architecture`. Call `dock_help()` with no
  args to list the current topics.

Before acting, call `dock_help()` plus the topic for the area you're touching
(e.g. `dock_help(topic='workflows')` before a reload/seed/test cycle).

## Durable working notes (defer to `dock_help` if these ever conflict)

- **Mutating ops are async.** `dock_reload`, `dock_seed`, `dock_test`, `dock_lint`, and
  `dock_lock_update` return a **job id** — poll `dock_job_status(job_id=...)` (or pass
  `wait=true`) instead of assuming completion.
- **Tests run in dedicated `*-test` containers** (e.g. `core-test`), separate from the app
  containers. Rebuild a test container with `dock_reload(service='core-test')`. Prefer a
  single-file `args` (e.g. `spec/models/user_spec.rb`) over the full suite for speed.
- **Interactive `binding.pry` can't go through MCP** — it needs a real host terminal:
  `just debug <service> <process>`. Ask the user to run it.
- **After pulling code:** `dock_reload(service)`; if migrations were added, follow with
  `dock_seed(service)`.
- **Empty DB / first run:** `dock_db_status()` → `dock_seed(service='all')` if empty.
- **Health:** `dock_doctor()` (environment), `dock_status(service)` (overmind processes),
  `dock_logs(service, process)` for errors.

## Environment broke mid-task?

If the environment itself breaks while you're doing something else (build failure, lock
file out of sync, container unhealthy, DB not seeded, dead overmind process, or an
`mcp__dock__*` tool returning an infra error) — **don't debug it inline.** Use the
**`repairing-dock-environment`** skill: it delegates the repair to a fresh-context
subagent so your task context stays clean, then summarizes every fix for the user.
