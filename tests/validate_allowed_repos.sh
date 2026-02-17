#!/usr/bin/env bash
# =============================================================================
# Validate .github/allowed_repos.json
# =============================================================================
# - File exists and is readable
# - Valid JSON
# - Root is an array of non-empty strings (owner/repo format)
# =============================================================================
set -e

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
ALLOWED_REPOS_FILE="${REPO_ROOT}/.github/allowed_repos.json"

if [ ! -f "$ALLOWED_REPOS_FILE" ]; then
  echo "::error::.github/allowed_repos.json not found"
  exit 1
fi

content=$(cat "$ALLOWED_REPOS_FILE")
if [ -z "$content" ]; then
  echo "::error::.github/allowed_repos.json is empty"
  exit 1
fi

if ! echo "$content" | jq empty 2>/dev/null; then
  echo "::error::.github/allowed_repos.json is not valid JSON"
  exit 1
fi

# Must be an array
if ! echo "$content" | jq -e 'type == "array"' >/dev/null 2>&1; then
  echo "::error::.github/allowed_repos.json must be a JSON array"
  exit 1
fi

# Each element must be a non-empty string
bad=$(echo "$content" | jq -r '.[] | select(type != "string" or length == 0) | .' 2>/dev/null | head -1)
if [ -n "$bad" ]; then
  echo "::error::.github/allowed_repos.json must contain only non-empty strings (owner/repo)"
  exit 1
fi

echo "✅ .github/allowed_repos.json is valid"
