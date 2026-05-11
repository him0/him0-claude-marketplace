#!/usr/bin/env bash
# PR Status Watcher for the Monitor tool.
#
# Polls GitHub Actions checks (and Circle CI status if available via `gh pr checks`)
# plus three GitHub comment surfaces every POLL_INTERVAL seconds, emitting
# structured events to stdout when state changes:
#   - pulls/<N>/comments    inline review comments
#   - pulls/<N>/reviews     review submissions (approve / request changes / overall)
#   - issues/<N>/comments   PR conversation comments
#
# Usage: bash watch-pr.sh [PR_NUMBER] [INTERVAL_SEC]
#
# Events:
#   [CI_FAILED]   CI: check "..." failed (provider: github-actions / circleci / other)
#   [GHA_FAILED]  GitHub Actions: check "..." failed  (alias used by skill)
#   [REVIEW_NEW]  @user commented on file:42: "..."
#   [REVIEW_NEW]  @user submitted review: "..."
#   [REVIEW_NEW]  @user commented on PR conversation: "..."
#   [CONFLICTING] PR became mergeable=CONFLICTING (merge conflict with base branch)
#   [ALL_PASSED]  All CI checks passed, no pending reviews
#   [PENDING]     CI checks still running (N/M completed)
#   [MERGED]      PR has been merged
#   [CLOSED]      PR has been closed without merging
#
# CircleCI: only status (FAILURE / PENDING / SUCCESS) is surfaced via `gh pr checks`.
# Detailed failure logs for CircleCI are NOT fetched; only GitHub Actions logs are
# pulled by the skill (via get-ci-logs.sh).

set -uo pipefail

MARKER='<!-- claude-code:auto-fix -->'

PR_NUMBER="${1:-}"
INTERVAL="${2:-60}"

if [ -z "$PR_NUMBER" ]; then
  PR_NUMBER="$(gh pr view --json number --jq .number 2>/dev/null || true)"
fi
if [ -z "$PR_NUMBER" ]; then
  echo "Error: Could not determine PR number. Pass as argument or run from a PR branch." >&2
  exit 1
fi

OWNER_REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)"
if [ -z "$OWNER_REPO" ]; then
  echo "Error: Could not resolve owner/repo from current directory." >&2
  exit 1
fi

BRANCH="$(gh pr view "$PR_NUMBER" --repo "$OWNER_REPO" --json headRefName --jq .headRefName 2>/dev/null || true)"
echo "Watching PR #$PR_NUMBER (repo: $OWNER_REPO, branch: $BRANCH, interval: ${INTERVAL}s)" >&2

# --- state files ---

STATE_DIR="$(mktemp -d -t watch-pr.XXXXXX)"
trap 'rm -rf "$STATE_DIR"' EXIT
CHECKS_FILE="$STATE_DIR/checks"
INLINE_IDS_FILE="$STATE_DIR/inline_ids"
PR_REVIEW_IDS_FILE="$STATE_DIR/pr_review_ids"
ISSUE_IDS_FILE="$STATE_DIR/issue_ids"
LAST_OVERALL_FILE="$STATE_DIR/last_overall"
LAST_MERGEABLE_FILE="$STATE_DIR/last_mergeable"
: >"$CHECKS_FILE"
: >"$INLINE_IDS_FILE"
: >"$PR_REVIEW_IDS_FILE"
: >"$ISSUE_IDS_FILE"
: >"$LAST_OVERALL_FILE"
: >"$LAST_MERGEABLE_FILE"

# --- helpers ---

emit() { printf '[%s] %s\n' "$1" "$2"; }

is_claude_reply() {
  [ -z "${1:-}" ] && return 1
  local trimmed
  trimmed="$(printf '%s' "$1" | awk '{ sub(/[[:space:]]+$/, ""); print }')"
  [[ "$trimmed" == *"$MARKER" ]]
}

truncate_str() {
  local max="$1" text
  text="$(printf '%s' "$2" | tr '\n\t' '  ' | sed -e 's/^ *//' -e 's/ *$//')"
  if [ "${#text}" -gt "$max" ]; then
    printf '%s...' "${text:0:$((max - 3))}"
  else
    printf '%s' "$text"
  fi
}

# Map ops on "<key>\t<value>" files
map_get() { awk -F'\t' -v k="$2" '$1 == k { print $2; exit }' "$1"; }
map_set() {
  local file="$1" key="$2" value="$3" tmp
  tmp="$(mktemp)"
  awk -F'\t' -v k="$key" -v v="$value" \
    'BEGIN{OFS="\t"} $1 == k { print k, v; found=1; next } { print } END { if (!found) print k, v }' \
    "$file" >"$tmp"
  mv "$tmp" "$file"
}

set_has() { grep -qxF "$2" "$1"; }
set_add() { printf '%s\n' "$2" >>"$1"; }

# --- pollers ---

# Emits "<name>\t<state>\t<provider>\t<link>" lines.
# state: SUCCESS / FAILURE / PENDING / SKIPPED / CANCELLED / etc. (gh pr checks)
poll_checks() {
  gh pr checks "$PR_NUMBER" --repo "$OWNER_REPO" --json name,state,link 2>/dev/null \
    | jq -r '
      .[] | [
        .name,
        .state,
        (if (.link // "" | test("github.com/.+/actions/runs/")) then "github-actions"
         elif (.link // "" | test("circleci.com/")) then "circleci"
         else "other" end),
        (.link // "")
      ] | @tsv
    ' 2>/dev/null
}

# Emits "<id>\t<user>\t<path>\t<line>\t<body>" lines.
# `gh api --paginate` auto-sets per_page=100; passing -F here would flip the request to POST.
poll_inline_comments() {
  gh api --paginate "repos/${OWNER_REPO}/pulls/${PR_NUMBER}/comments" \
    --jq '.[] | [.id, .user.login, .path, (.line // ""), ((.body // "") | gsub("\n"; " ") | gsub("\t"; " "))] | @tsv' 2>/dev/null
}

# Emits "<id>\t<user>\t<body>" lines.
poll_pr_reviews() {
  gh pr view "$PR_NUMBER" --repo "$OWNER_REPO" --json reviews 2>/dev/null \
    | jq -r '.reviews[] | [.id, .author.login, ((.body // "") | gsub("\n"; " ") | gsub("\t"; " "))] | @tsv' 2>/dev/null
}

# Emits "<id>\t<user>\t<body>" lines.
poll_issue_comments() {
  gh api --paginate "repos/${OWNER_REPO}/issues/${PR_NUMBER}/comments" \
    --jq '.[] | [.id, .user.login, ((.body // "") | gsub("\n"; " ") | gsub("\t"; " "))] | @tsv' 2>/dev/null
}

# Emits "<state>\t<mergeable>" — state は OPEN/MERGED/CLOSED、mergeable は MERGEABLE/CONFLICTING/UNKNOWN
poll_pr_meta() {
  gh pr view "$PR_NUMBER" --repo "$OWNER_REPO" --json state,mergeable \
    --jq '[.state, (.mergeable // "UNKNOWN")] | @tsv' 2>/dev/null
}

# --- overall status ---

compute_overall() {
  awk -F'\t' '
    $2 == "" { next }
    {
      total++
      s = toupper($2)
      if (s == "FAILURE" || s == "FAIL" || s == "FAILED" || s == "FAILING") failed++
      else if (s == "PENDING" || s == "QUEUED" || s == "IN_PROGRESS" || s == "WAITING" || s == "REQUESTED") pending++
      else if (s == "SUCCESS" || s == "SKIPPED" || s == "NEUTRAL" || s == "CANCELLED" || s == "CANCELED" || s == "STALE") passed++
    }
    END {
      if (total == 0) print "unknown"
      else if (failed > 0) print "failed"
      else if (pending > 0) print "pending"
      else if (passed == total) print "all_passed"
      else print "unknown"
    }
  ' "$CHECKS_FILE"
}

count_completed() {
  awk -F'\t' '
    {
      s = toupper($2)
      if (s == "SUCCESS" || s == "FAILURE" || s == "FAIL" || s == "FAILED" || s == "FAILING" ||
          s == "SKIPPED" || s == "NEUTRAL" || s == "CANCELLED" || s == "CANCELED" || s == "STALE") c++
    }
    END { print c+0 }
  ' "$CHECKS_FILE"
}

count_total() {
  awk -F'\t' '$2 != "" { c++ } END { print c+0 }' "$CHECKS_FILE"
}

# --- seed ---

seed_state() {
  local name state provider link id user path line body
  while IFS=$'\t' read -r name state provider link; do
    [ -n "$name" ] && map_set "$CHECKS_FILE" "$name" "$state"
  done < <(poll_checks)
  while IFS=$'\t' read -r id user path line body; do
    [ -n "$id" ] && set_add "$INLINE_IDS_FILE" "$id"
  done < <(poll_inline_comments)
  while IFS=$'\t' read -r id user body; do
    [ -n "$id" ] && set_add "$PR_REVIEW_IDS_FILE" "$id"
  done < <(poll_pr_reviews)
  while IFS=$'\t' read -r id user body; do
    [ -n "$id" ] && set_add "$ISSUE_IDS_FILE" "$id"
  done < <(poll_issue_comments)

  compute_overall >"$LAST_OVERALL_FILE"

  local pr_state mergeable_init
  IFS=$'\t' read -r pr_state mergeable_init < <(poll_pr_meta)
  printf '%s' "$mergeable_init" >"$LAST_MERGEABLE_FILE"

  local inline_n pr_n issue_n
  inline_n="$(awk 'END{print NR+0}' "$INLINE_IDS_FILE")"
  pr_n="$(awk 'END{print NR+0}' "$PR_REVIEW_IDS_FILE")"
  issue_n="$(awk 'END{print NR+0}' "$ISSUE_IDS_FILE")"
  echo "Initial state: $(count_total) checks, $inline_n inline comments, $pr_n reviews, $issue_n conversation comments, mergeable=$mergeable_init" >&2
}

# --- main poll cycle ---

poll_and_emit() {
  local pr_state mergeable
  IFS=$'\t' read -r pr_state mergeable < <(poll_pr_meta)
  if [ "$pr_state" = "MERGED" ]; then
    emit MERGED "PR #$PR_NUMBER has been merged"
    exit 0
  fi
  if [ "$pr_state" = "CLOSED" ]; then
    emit CLOSED "PR #$PR_NUMBER has been closed without merging"
    exit 0
  fi

  local has_new=false name state provider link id user path line body prev loc

  # UNKNOWN は GitHub が再計算中なので無視 (= MERGEABLE/CONFLICTING への確定遷移のみ拾う)
  local last_mergeable
  last_mergeable="$(cat "$LAST_MERGEABLE_FILE")"
  if [ -n "$mergeable" ] && [ "$mergeable" != "UNKNOWN" ] && [ "$mergeable" != "$last_mergeable" ]; then
    if [ "$mergeable" = "CONFLICTING" ]; then
      emit CONFLICTING "PR #$PR_NUMBER has merge conflicts with base branch"
      has_new=true
    fi
    printf '%s' "$mergeable" >"$LAST_MERGEABLE_FILE"
  fi

  while IFS=$'\t' read -r name state provider link; do
    [ -z "$name" ] && continue
    prev="$(map_get "$CHECKS_FILE" "$name")"
    if [ "$prev" != "$state" ]; then
      local upper="${state^^}"
      if [ "$upper" = "FAILURE" ] || [ "$upper" = "FAIL" ] || [ "$upper" = "FAILED" ] || [ "$upper" = "FAILING" ]; then
        if [ "$provider" = "github-actions" ]; then
          emit GHA_FAILED "GitHub Actions: check \"$name\" failed"
        else
          emit CI_FAILED "$provider: check \"$name\" failed"
        fi
        has_new=true
      fi
      map_set "$CHECKS_FILE" "$name" "$state"
    fi
  done < <(poll_checks)

  while IFS=$'\t' read -r id user path line body; do
    [ -z "$id" ] && continue
    if ! set_has "$INLINE_IDS_FILE" "$id"; then
      set_add "$INLINE_IDS_FILE" "$id"
      if is_claude_reply "$body"; then continue; fi
      [ -n "$line" ] && loc="$path:$line" || loc="$path"
      emit REVIEW_NEW "@$user commented on $loc: \"$(truncate_str 80 "$body")\""
      has_new=true
    fi
  done < <(poll_inline_comments)

  while IFS=$'\t' read -r id user body; do
    [ -z "$id" ] && continue
    if ! set_has "$PR_REVIEW_IDS_FILE" "$id"; then
      set_add "$PR_REVIEW_IDS_FILE" "$id"
      if is_claude_reply "$body"; then continue; fi
      if [ -n "$body" ]; then
        emit REVIEW_NEW "@$user submitted review: \"$(truncate_str 80 "$body")\""
      else
        emit REVIEW_NEW "@$user submitted review"
      fi
      has_new=true
    fi
  done < <(poll_pr_reviews)

  while IFS=$'\t' read -r id user body; do
    [ -z "$id" ] && continue
    if ! set_has "$ISSUE_IDS_FILE" "$id"; then
      set_add "$ISSUE_IDS_FILE" "$id"
      if is_claude_reply "$body"; then continue; fi
      emit REVIEW_NEW "@$user commented on PR conversation: \"$(truncate_str 80 "$body")\""
      has_new=true
    fi
  done < <(poll_issue_comments)

  if [ "$has_new" = false ]; then
    local overall last
    overall="$(compute_overall)"
    last="$(cat "$LAST_OVERALL_FILE")"
    if [ "$overall" != "$last" ]; then
      if [ "$overall" = "all_passed" ]; then
        emit ALL_PASSED "All CI checks passed, no pending reviews"
      elif [ "$overall" = "pending" ]; then
        emit PENDING "CI checks still running ($(count_completed)/$(count_total) completed)"
      fi
      printf '%s' "$overall" >"$LAST_OVERALL_FILE"
    fi
  fi
}

# --- main ---

seed_state

while true; do
  sleep "$INTERVAL"
  poll_and_emit || echo "[stderr] Poll error" >&2
done
