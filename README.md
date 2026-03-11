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
