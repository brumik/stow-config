#!/usr/bin/env bash
# Fully scripted GitHub digest for the /morning skill — no LLM judgment involved.
# Usage: github.sh actionable | github.sh your-prs
set -euo pipefail

me="$(gh api user --jq '.login')"

my_prs_json="$(gh search prs --author=@me --state=open --json number,title,url,repository,isDraft)"

link_for() {
  local type="$1" html_url="$2" api_url="$3"
  local n="${api_url##*/}"
  case "$type" in
    PullRequest) echo "${html_url}/pull/${n}" ;;
    Issue) echo "${html_url}/issues/${n}" ;;
    *) echo "$html_url" ;;
  esac
}

cmd="${1:-actionable}"

case "$cmd" in

your-prs)
  found=0
  while IFS=$'\t' read -r number repo title url draft; do
    blocking="$(gh api "repos/${repo}/pulls/${number}/reviews" --jq '
      group_by(.user.login)
      | map(max_by(.submitted_at))
      | map(select(.state=="CHANGES_REQUESTED"))
      | length > 0
    ')"
    if [ "$blocking" = "true" ]; then
      suffix=""
      [ "$draft" = "true" ] && suffix=" (draft)"
      echo "- [${title}${suffix}](${url}) — changes requested"
      found=1
    fi
  done < <(echo "$my_prs_json" | jq -r '.[] | [.number, .repository.nameWithOwner, .title, .url, .isDraft] | @tsv')
  [ "$found" = "1" ] || echo "NONE"
  ;;

actionable)
  notifications_json="$(gh api notifications --jq '[.[] | select(.unread)]')"
  my_pr_keys="$(echo "$my_prs_json" | jq -r '.[] | "\(.repository.nameWithOwner)#\(.number)"')"
  found=0

  # 1. Assigned directly to me (always personal — assignment has no team form)
  while IFS=$'\t' read -r type html_url api_url title; do
    link="$(link_for "$type" "$html_url" "$api_url")"
    echo "- [${title}](${link}) — assigned to you"
    found=1
  done < <(echo "$notifications_json" | jq -r '.[] | select(.reason=="assign") | [.subject.type, .repository.html_url, .subject.url, .subject.title] | @tsv')

  # 2. Personally requested for review (not just team-requested)
  while IFS=$'\t' read -r repo html_url api_url title; do
    n="${api_url##*/}"
    reviewers="$(gh api "repos/${repo}/pulls/${n}" --jq '.requested_reviewers[].login')"
    if grep -qx "$me" <<<"$reviewers"; then
      echo "- [${title}](${html_url}/pull/${n}) — review requested"
      found=1
    fi
  done < <(echo "$notifications_json" | jq -r '.[] | select(.reason=="review_requested" and .subject.type=="PullRequest") | [.repository.full_name, .repository.html_url, .subject.url, .subject.title] | @tsv')

  # 3. Human (non-bot) comment on a PR I authored
  while IFS=$'\t' read -r repo html_url api_url title latest_comment_url; do
    n="${api_url##*/}"
    key="${repo}#${n}"
    grep -qx "$key" <<<"$my_pr_keys" || continue
    [ -n "$latest_comment_url" ] && [ "$latest_comment_url" != "null" ] || continue
    is_bot="$(gh api "$latest_comment_url" --jq '.user.type=="Bot"' 2>/dev/null || echo true)"
    if [ "$is_bot" != "true" ]; then
      commenter="$(gh api "$latest_comment_url" --jq '.user.login')"
      echo "- [${title}](${html_url}/pull/${n}) — comment from ${commenter}"
      found=1
    fi
  done < <(echo "$notifications_json" | jq -r '.[] | select(.reason=="comment" and .subject.type=="PullRequest") | [.repository.full_name, .repository.html_url, .subject.url, .subject.title, (.subject.latest_comment_url // "")] | @tsv')

  [ "$found" = "1" ] || echo "NONE"
  ;;

*)
  echo "usage: $0 {actionable|your-prs}" >&2
  exit 1
  ;;
esac
