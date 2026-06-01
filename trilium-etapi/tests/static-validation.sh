#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

make_dir=$(make print | awk '/^dir:/ {print $2}')
[[ "$make_dir" == "trilium-etapi" ]] || fail "Makefile SKILL_DIR must be trilium-etapi, got '$make_dir'"

[[ -x scripts/list-api-endpoints.sh ]] || fail "scripts/list-api-endpoints.sh must exist and be executable"
[[ -x scripts/validate-live.sh ]] || fail "scripts/validate-live.sh must exist and be executable"
[[ -x scripts/probe-internal-api.sh ]] || fail "scripts/probe-internal-api.sh must exist and be executable"

grep -q 'TRILIUM_TOKEN' SKILL.md || fail "SKILL.md must document TRILIUM_TOKEN"
grep -q 'validate-live.sh' SKILL.md || fail "SKILL.md must document live validation"
grep -q 'probe-internal-api.sh' SKILL.md || fail "SKILL.md must document Internal API probing"

printf 'static validation passed\n'
