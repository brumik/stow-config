#!/usr/bin/env bash
# Formats a jira_search MCP tool result (JSON on stdin, {"result": "<json-string>"})
# into markdown link bullets. No LLM judgment involved.
set -euo pipefail

jq -r '
  (.result | fromjson) as $r
  | if ($r.issues | length) == 0 then "NONE" else
    $r.issues[]
    | "- [\(.key)](https://modmedrnd.atlassian.net/browse/\(.key)) — \(.summary) — \(.status.name)"
  end
'
