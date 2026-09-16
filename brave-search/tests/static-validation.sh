#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

make_dir=$(make print | awk '/^dir:/ {print $2}')
[[ "$make_dir" == "brave-search" ]] || fail "Makefile SKILL_DIR must be brave-search, got '$make_dir'"

grep -q 'BRAVE_SEARCH_API_KEY' SKILL.md || fail "SKILL.md must document BRAVE_SEARCH_API_KEY"
grep -q 'BRAVE_SEARCH_BASE_URL' SKILL.md || fail "SKILL.md must document BRAVE_SEARCH_BASE_URL"
grep -q 'X-Subscription-Token' SKILL.md || fail "SKILL.md must document the X-Subscription-Token header"
grep -q 'api.search.brave.com' SKILL.md || fail "SKILL.md must document the official base URL api.search.brave.com"
grep -q '/res/v1/web/search' SKILL.md || fail "SKILL.md must document the /res/v1/web/search endpoint"

[[ -f api-reference.md ]] || fail "api-reference.md must exist"
grep -q '/res/v1/news/search' api-reference.md || fail "api-reference.md must document the news endpoint"
grep -q '/res/v1/images/search' api-reference.md || fail "api-reference.md must document the images endpoint"

printf 'static validation passed\n'