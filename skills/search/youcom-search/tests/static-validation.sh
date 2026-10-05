#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

make_dir=$(make print | awk '/^dir:/ {print $2}')
[[ "$make_dir" == "youcom-search" ]] || fail "Makefile SKILL_DIR must be youcom-search, got '$make_dir'"

grep -q 'YDC_API_KEY' SKILL.md || fail "SKILL.md must document YDC_API_KEY"
grep -q 'YOU_API_BASE_URL' SKILL.md || fail "SKILL.md must document YOU_API_BASE_URL"
grep -q 'api.you.com' SKILL.md || fail "SKILL.md must document the api.you.com base URL"
grep -q '/api/search' SKILL.md || fail "SKILL.md must document /api/search"
grep -q '/api/contents' SKILL.md || fail "SKILL.md must document /api/contents"
grep -q 'Bearer' SKILL.md || fail "SKILL.md must document Bearer auth"

[[ -f api-reference.md ]] || fail "api-reference.md must exist"
grep -q 'research' api-reference.md || fail "api-reference.md must document the research endpoint"

printf 'static validation passed\n'