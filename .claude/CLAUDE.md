# Global instructions

## tmux tab naming

When running inside tmux (`$TMUX` is set), keep this session's window named `✳ <short-task>` — a
short label for the current work with a `✳ ` marker prefix — so concurrent Claude tabs are
distinguishable. Set it when starting a task and update it as the focus shifts. Examples:
`✳ voicemail-rails8`, `✳ jira-triage`, `✳ klara-10204`.

```bash
[ -z "$TMUX" ] || { tmux set-window-option -t "$TMUX_PANE" automatic-rename off; \
  tmux rename-window -t "$TMUX_PANE" "✳ <short-task>"; } 2>/dev/null || true
```

Always target `$TMUX_PANE` (the pane running this session), never "the current window" — the
client's active tab may be a different window. `automatic-rename` defaults to `on`, so the
`set-window-option ... off` is required or tmux will overwrite the name.
