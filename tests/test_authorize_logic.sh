#!/usr/bin/env bash
# =============================================================================
# Test authorize logic (same as workflow: same-repo shortcut + allowlist check)
# =============================================================================
# Uses local .github/allowed_repos.json (no curl). Verifies:
# - Same repo (THIS_REPO) is always authorized
# - Repo in allowed_repos.json is authorized
# - Repo not in list is denied
# =============================================================================
set -e

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
ALLOWED_REPOS_FILE="${REPO_ROOT}/.github/allowed_repos.json"
THIS_REPO="kubev2v/migration-planner-client-generator"

assert_authorized() {
  local caller_repo="$1"
  local list_content="$2"
  if [ "$caller_repo" = "$THIS_REPO" ]; then
    return 0
  fi
  echo "$list_content" | jq -e --arg repo "$caller_repo" 'index($repo) != null' >/dev/null
}

assert_unauthorized() {
  local caller_repo="$1"
  local list_content="$2"
  if [ "$caller_repo" = "$THIS_REPO" ]; then
    echo "Expected unauthorized but same-repo is always allowed: $caller_repo"
    return 1
  fi
  ! echo "$list_content" | jq -e --arg repo "$caller_repo" 'index($repo) != null' >/dev/null 2>&1
}

list=$(cat "$ALLOWED_REPOS_FILE")
if ! echo "$list" | jq empty 2>/dev/null; then
  echo "::error::allowed_repos.json is not valid JSON (run validate_allowed_repos.sh first)"
  exit 1
fi

errors=0

# Same repo is always authorized (no list lookup)
if assert_authorized "$THIS_REPO" "[]"; then
  echo "✅ Same-repo ($THIS_REPO) is authorized (shortcut)"
else
  echo "::error::Same-repo should be authorized"
  errors=$((errors + 1))
fi

# First repo in the list should be authorized when used as caller
first_repo=$(echo "$list" | jq -r '.[0]')
if [ -n "$first_repo" ] && [ "$first_repo" != "null" ]; then
  if assert_authorized "$first_repo" "$list"; then
    echo "✅ Caller in list ($first_repo) is authorized"
  else
    echo "::error::Caller in list ($first_repo) should be authorized"
    errors=$((errors + 1))
  fi
fi

# Random repo not in list should be unauthorized
if assert_unauthorized "other-org/other-repo" "$list"; then
  echo "✅ Caller not in list (other-org/other-repo) is denied"
else
  echo "::error::Caller not in list should be denied"
  errors=$((errors + 1))
fi

# Partial match should be denied (exact match only)
if echo "$list" | jq -e --arg repo "kubev2v/migration-planner-fake" 'index($repo) != null' >/dev/null 2>&1; then
  echo "::error::Partial repo name should not match"
  errors=$((errors + 1))
else
  echo "✅ Partial repo name does not match (exact match only)"
fi

if [ $errors -gt 0 ]; then
  echo "::error::$errors assertion(s) failed"
  exit 1
fi

echo "✅ All authorize logic tests passed"
