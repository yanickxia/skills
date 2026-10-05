#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

make_dir=$(make print | awk '/^dir:/ {print $2}')
[[ "$make_dir" == "serpapi-search" ]] || fail "Makefile SKILL_DIR must be serpapi-search, got '$make_dir'"

[[ -f SKILL.md ]] || fail "SKILL.md must exist"
grep -q 'SERPAPI_API_KEY' SKILL.md || fail "SKILL.md must document SERPAPI_API_KEY"
grep -q 'SERPAPI_BASE_URL' SKILL.md || fail "SKILL.md must document SERPAPI_BASE_URL"
grep -q 'search.json' SKILL.md || fail "SKILL.md must document search.json"
grep -q 'api_key' SKILL.md || fail "SKILL.md must document the api_key query parameter"
grep -q 'serpapi.com' SKILL.md || fail "SKILL.md must reference serpapi.com"

[[ -f api-reference.md ]] || fail "api-reference.md must exist"
grep -q 'organic_results' api-reference.md || fail "api-reference.md must document organic_results"
grep -q 'account.json' api-reference.md || fail "api-reference.md must document account.json"

printf 'static validation passed\n'