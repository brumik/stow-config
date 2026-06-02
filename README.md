# stow-config

macOS dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).

## What's Included

- **Neovim** - Lazy.nvim config with Everforest theme
- **Kitty** - Terminal emulator config
- **Tmux** - Terminal multiplexer with tmux-sessionizer
- **AeroSpace** - Tiling window manager for macOS
- **Zsh** - Shell aliases and prompt
- **Git** - Global git config with diffnav
- **SSH** - SSH client config
- **gh-dash** - GitHub CLI dashboard
- **tms** - tmux-sessionizer project picker
- **Claude Code** - `~/.claude/settings.json` and a stow-managed `~/.claude/skills/` directory

## Initial Setup

Install prerequisites:

```bash
./install.sh
```

Apply dotfiles (creates symlinks from this repo into `$HOME`):

```bash
stow -d ~/Documents -t ~ stow-config
```

## Refreshing Stow After Adding New Files

When you add new dotfiles to this repo, stow needs to be re-run to create
the new symlinks. Existing symlinks are left untouched.

```bash
# Re-stow to pick up any new files
stow -R -d ~/Documents -t ~ stow-config
```

The `-R` flag (restow) first unstows and then re-stows, which cleanly
handles additions, removals, and structural changes.

If you only added files (no deletions or moves), a plain `stow` call also
works since stow is idempotent for existing symlinks:

```bash
stow -d ~/Documents -t ~ stow-config
```

### Adding a new dotfile

1. Place the file in this repo mirroring its path relative to `$HOME`.
   For example, to manage `~/.config/foo/bar.toml`:
   ```bash
   mkdir -p .config/foo
   cp ~/.config/foo/bar.toml .config/foo/bar.toml
   ```
2. Re-stow:
   ```bash
   stow -R -d ~/Documents -t ~ stow-config
   ```
3. Commit and push.

## Claude Code

Only specific, hand-editable files inside `~/.claude` are managed here. The rest
of `~/.claude` (session history, caches, `projects/`, `backups/`, logs, plugins)
is machine-local runtime state and is **deliberately not** version-controlled.

Managed paths:

- `.claude/settings.json` — symlinked to `~/.claude/settings.json`. Also records
  which plugins are enabled (`enabledPlugins`), so plugin choices are reproducible
  (see _Plugins_ below).
- `.claude/skills/` — folded into a single symlink at `~/.claude/skills`, so any
  skill you author in this repo automatically shows up in Claude Code (no re-stow
  needed for new skills inside the folder).

Because `~/.claude` already exists as a real directory full of runtime state,
stow leaves it in place and only symlinks the two managed entries inside it.

### Skills

Skills you write live in `.claude/skills/<name>/SKILL.md` and load automatically
(short name `/<name>`). Included:

- **dock** — a "pure pointer" skill for driving the Klara platform via the Dock
  MCP. It copies no service lists or commands; instead it defers to the MCP's own
  live self-documentation (`dock_help` + tool-schema enums) so it can never drift
  when the MCP changes, and holds only durable workflow gotchas.

> Note: Claude Code's built-in and plugin-provided skills are not stored here —
> they live under `~/.claude/plugins/` and are reinstalled automatically from
> their marketplaces, so there is nothing to version. This repo only tracks
> skills you write yourself.

### Plugins

Plugin _content_ is **not** versioned (it lives under `~/.claude/plugins/` and
auto-updates from its marketplace). Only the `enabledPlugins` entry in the tracked
`settings.json` makes a plugin reproducible. On a fresh machine, `stow` restores
that entry and Claude Code re-installs the plugin from the always-known official
marketplace.

Currently enabled:

- **superpowers** (`superpowers@claude-plugins-official`) — Jesse Vincent's agentic
  skills framework (brainstorm → plan → TDD → review). Reinstall manually with
  `claude plugin install superpowers@claude-plugins-official` if needed.
- **playwright** (`playwright@claude-plugins-official`) — Microsoft's browser-automation
  MCP server (`npx @playwright/mcp@latest`), used in place of a separately configured
  MCP server. Runs the browser **locally**, so it can drive the local Dock stack
  (`https://*.modmed.dev`); first launch may download a browser.

> MCP servers note: the `dock` and `klarity` MCP servers are remote HTTP endpoints
> (`*.modmed.dev/mcp`) configured at user scope in `~/.claude.json`. That file is **not**
> stow-managed (it carries per-project state), so those two are **not** reproducible from
> this repo — re-add them on a new machine with
> `claude mcp add --transport http <name> <url>`. Playwright avoids that gap by being a
> plugin (enablement captured above).

## Migrating From the Old Config Repo

If you previously used stow from `~/config/non-nix/stow/`, follow these
steps to migrate to this standalone repo.

### 1. Unstow the old location

First, remove the symlinks that point to the old repo:

```bash
stow -D -d ~/config/non-nix -t ~ stow
```

The `-D` flag deletes (unstows) the symlinks without touching the actual
config files in the repo.

### 2. Clone this repo

```bash
git clone git@github.com:brumik/stow-config.git ~/Documents/stow-config
```

### 3. Stow from the new location

```bash
stow -d ~/Documents -t ~ stow-config
```

### 4. Verify

Check that symlinks point to the new repo:

```bash
ls -la ~/.zshrc
# Should show: .zshrc -> Documents/stow-config/.zshrc

ls -la ~/.config/nvim
# Should show: nvim -> ../../Documents/stow-config/.config/nvim
```

### 5. Clean up the old repo

Once verified, you can remove `non-nix/stow/` from the old config repo.
