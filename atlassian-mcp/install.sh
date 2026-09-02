#!/usr/bin/env bash
# Installs/reloads the standalone Atlassian (Jira + Confluence) MCP launchd agent.
#
# Copies the plist to ~/Library/LaunchAgents (a real copy, not a symlink — launchd
# agents can't read files under ~/Documents/stow-config, see the plist's own
# comment) and (re)loads it. Requires JIRA_API_TOKEN / CONFLUENCE_API_TOKEN to
# already be exported from ~/.zprofile (see ../.zprofile.sample).

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
label="com.levente.atlassian-mcp"
plist_src="$script_dir/$label.plist"
plist_dst="$HOME/Library/LaunchAgents/$label.plist"
uid="$(id -u)"

cp "$plist_src" "$plist_dst"
echo "Installed $plist_dst"

launchctl bootout "gui/$uid/$label" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$uid" "$plist_dst"
echo "Loaded $label"

launchctl print "gui/$uid/$label" | head -5
