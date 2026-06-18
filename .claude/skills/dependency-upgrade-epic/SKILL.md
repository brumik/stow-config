---
name: dependency-upgrade-epic
description: Use when working a batch of dependency/version-upgrade tickets on a klara-backend repo — Snyk security upgrades, internal "bump gem X to Y", or a full EOL framework migration. Covers triage, isolated-worktree attempts, discovering coupling into a merge stack, serial in-container Dock verification, fixing root causes, and the user-prompted finish (review-ready PRs + Jira).
---

# Dependency upgrade epic

Playbook for taking a set of upgrade tickets (Snyk vulns, "update X to Y", or an EOL framework
migration) from open → review-ready PRs on a klara-backend repo. The repo/env **facts** live in
memory (see end) — this is the *procedure* that ties them together.

## 1. Triage & scope
- Read each ticket's acceptance criteria; capture the **exact target versions**.
- `gh pr list` for existing **Snyk single-gem PRs** — they carry known-good pins to reuse, and
  you'll `Supersede` them in your PR once yours lands.
- Flag tickets that touch the same `Gemfile` / lockfile — those will probably couple (§3).

## 2. Attempt each ticket in an isolated worktree
- Branch **fresh from the repo's integration branch** (e.g. `rc` for voicemail) into its own
  `git worktree`; one **draft PR** per ticket, making only that ticket's change.
- This pass is for **discovery**: which upgrades stand alone vs. which won't resolve without another.

## 3. Discover coupling → restructure into a bottom-up stack
- When bump A won't lock without bump B (classic: `rack 3 ⇐ Sidekiq 7`, via a transitive
  `rack < 3` pin), **don't fight it standalone.** Rebase the branches into a dependency **stack**,
  each PR targeting the one below; merge bottom-up.
- If the stack needs a prerequisite that **has no ticket**, surface it — creating it is
  user-prompted (§6), not automatic.

## 4. Verify serially, in-container
- Dock bind-mounts **one** repo path → only one branch is verifiable at a time. Per branch:
  checkout → `dock_reload` the app + `*-test` containers → run the full suite → record results.
- All ruby/bundle runs **in-container** (dock ruby), never host. See the `dock` skill.

## 5. Fix root causes, not symptoms
- A spec that fails after a bump usually has a real cause — find it before bumping more versions.
  (Our "arbre/ActiveAdmin" failure was a dead 2021 association; one deleted line fixed it.)
- **No beta / unreleased deps** to paper over a gap in a stability/EOL upgrade — that trades one
  problem for several.
- Revert host-tooling lockfile noise (bundler-marker / whitespace flips); regenerate locks
  in-container.
- Internal gems: source from **GitHub Packages**, and the **CI workflow version must auth
  Packages** — both easy to miss (facts in memory).

## 6. Finish — only when the user asks
Not automatic. While PRs are in draft, their running progress comments (e2e results, restack
notes, root-cause corrections) are **part of the user's review** — leave them.
- **Review-ready formatting** (trim body, fold-and-delete working comments) → the `review-ready-pr`
  skill, on request.
- **Jira** (move to Code Review, set fix versions, create a missing prerequisite ticket) →
  `klara-jira-ticket-creation` conventions, on request.

## Facts live in memory (don't duplicate)
`always-use-dock-ruby`, `klara-jira-ticket-creation`, `never-merge`,
`draft-pr-updates-and-jira-are-user-prompted`, plus the per-epic state file. Consult those for the
concrete commands, field values, and version pins.
