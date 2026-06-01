#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
url=${TRILIUM_URL:-}
timeout=${TRILIUM_CURL_TIMEOUT:-8}
etapi_token=${TRILIUM_TOKEN:-}
internal_token=${TRILIUM_INTERNAL_TOKEN:-}
session_cookie=${TRILIUM_SESSION_COOKIE:-${TRILIUM_COOKIE:-}}
password=${TRILIUM_PASSWORD:-}
require_auth=${TRILIUM_INTERNAL_REQUIRE_AUTH:-0}

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

usage() {
  cat <<'USAGE'
Usage: TRILIUM_URL=http://localhost:37840 scripts/probe-internal-api.sh

Safely probes Trilium Internal API availability. It does not run destructive
endpoints. Authenticated Internal API requests need one of:

  TRILIUM_INTERNAL_TOKEN="..."       sent as Authorization: Bearer ...
  TRILIUM_SESSION_COOKIE="..."       sent as Cookie: ...
  TRILIUM_PASSWORD="..."             used to mint an Internal API token via /api/login/token

Optional:
  TRILIUM_TOKEN="..."                proves ETAPI tokens do not authenticate /api
  TRILIUM_INTERNAL_REQUIRE_AUTH=1    fail if no Internal API auth is available
USAGE
}

[[ ${1:-} == "-h" || ${1:-} == "--help" ]] && { usage; exit 0; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'missing required command: %s\n' "$1" >&2
    exit 2
  }
}

require_cmd curl
if [[ -n "$password" ]]; then
  require_cmd jq
fi

detect_url() {
  [[ -n "$url" ]] && return
  local candidate body
  for candidate in http://localhost:37840 http://localhost:37740 http://localhost:8080; do
    body=$(curl -sS --max-time 3 "$candidate/api/health-check" 2>/dev/null || true)
    if [[ "$body" == *'"status":"ok"'* ]]; then
      url=$candidate
      return
    fi
  done
  printf 'FAIL: TRILIUM_URL was not set and auto-detection failed\n' >&2
  exit 1
}

request_code() {
  local outfile=$1 endpoint=$2 auth_mode=${3:-none}
  shift 3 || true
  local -a auth_args=()

  case "$auth_mode" in
    none) ;;
    etapi-raw) auth_args=(-H "Authorization: $etapi_token") ;;
    etapi-bearer) auth_args=(-H "Authorization: Bearer $etapi_token") ;;
    etapi-basic)
      local basic
      basic=$(printf 'etapi:%s' "$etapi_token" | base64 | tr -d '\n')
      auth_args=(-H "Authorization: Basic $basic")
      ;;
    internal-token) auth_args=(-H "Authorization: Bearer $internal_token") ;;
    cookie) auth_args=(-H "Cookie: $session_cookie") ;;
    *)
      printf 'FAIL: unknown auth mode: %s\n' "$auth_mode" >&2
      exit 2
      ;;
  esac

  curl -sS --max-time "$timeout" -o "$outfile" -w '%{http_code}' "$url$endpoint" "${auth_args[@]}" "$@" || true
}

ok() {
  printf 'ok - %s\n' "$1"
}

skip() {
  printf 'skip - %s (%s)\n' "$1" "$2"
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

detect_url
url=${url%/}

endpoints_file="$tmpdir/internal-endpoints.txt"
"$script_dir/list-api-endpoints.sh" --kind internal >"$endpoints_file"
endpoint_count=$(wc -l <"$endpoints_file" | tr -d ' ')
printf 'internal endpoints discovered: %s\n' "$endpoint_count"

health_out="$tmpdir/health.out"
health_code=$(request_code "$health_out" /api/health-check none)
[[ "$health_code" == "200" ]] || fail "GET /api/health-check returned $health_code"
grep -q '"status":"ok"' "$health_out" || fail 'GET /api/health-check did not return status ok'
ok 'GET /api/health-check public'

app_out="$tmpdir/app-info-no-auth.out"
app_code=$(request_code "$app_out" /api/app-info none)
if [[ "$app_code" == "401" ]]; then
  ok 'GET /api/app-info rejects missing session'
elif [[ "$app_code" == "200" ]]; then
  ok 'GET /api/app-info public on this instance'
else
  fail "GET /api/app-info without auth returned $app_code"
fi

setup_out="$tmpdir/setup-status.out"
setup_code=$(request_code "$setup_out" /api/setup/status none)
[[ "$setup_code" == "200" ]] || fail "GET /api/setup/status returned $setup_code"
grep -q '"isInitialized"' "$setup_out" || fail 'GET /api/setup/status response did not include isInitialized'
ok 'GET /api/setup/status public'

if [[ -n "$etapi_token" ]]; then
  for mode in etapi-raw etapi-bearer etapi-basic; do
    out="$tmpdir/$mode.out"
    code=$(request_code "$out" /api/app-info "$mode")
    if [[ "$code" == "401" ]]; then
      ok "GET /api/app-info rejects $mode"
    elif [[ "$code" == "200" ]]; then
      ok "GET /api/app-info accepts $mode"
    else
      fail "GET /api/app-info with $mode returned $code"
    fi
  done
else
  skip 'ETAPI token rejection probe' 'TRILIUM_TOKEN not set'
fi

auth_mode=
if [[ -n "$internal_token" ]]; then
  auth_mode=internal-token
elif [[ -n "$session_cookie" ]]; then
  auth_mode=cookie
elif [[ -n "$password" ]]; then
  token_out="$tmpdir/login-token.out"
  token_code=$(curl -sS --max-time "$timeout" -o "$token_out" -w '%{http_code}' \
    -X POST "$url/api/login/token" \
    -H 'Content-Type: application/json' \
    --data-binary "$(printf '%s' "$password" | jq -Rs '{password: ., tokenName: "codex-internal-api-probe"}')")
  [[ "$token_code" == "201" ]] || fail "POST /api/login/token returned $token_code: $(head -c 200 "$token_out")"
  internal_token=$(jq -r '.authToken // empty' "$token_out")
  [[ -n "$internal_token" ]] || fail 'POST /api/login/token did not return authToken'
  auth_mode=internal-token
  ok 'POST /api/login/token'
fi

if [[ -z "$auth_mode" ]]; then
  skip 'authenticated Internal API coverage' 'set TRILIUM_INTERNAL_TOKEN, TRILIUM_SESSION_COOKIE, or TRILIUM_PASSWORD'
  if [[ "$require_auth" == "1" ]]; then
    fail 'Internal API auth is required but was not provided'
  fi
  printf 'summary: public/auth-boundary probes completed; authenticated endpoints not executed\n'
  exit 0
fi

safe_gets=(
  /api/app-info
  /api/tree
  /api/options
  /api/attribute-names
  /api/autocomplete/notesCount
  /api/search/codex-etapi-probe-no-match
  /api/quick-search/codex-etapi-probe-no-match
  /api/recent-changes/root
)

passed=0
for endpoint in "${safe_gets[@]}"; do
  out="$tmpdir/safe-${passed}.out"
  code=$(request_code "$out" "$endpoint" "$auth_mode")
  [[ "$code" == "200" ]] || fail "GET $endpoint returned $code: $(head -c 200 "$out")"
  ok "GET $endpoint"
  passed=$((passed + 1))
done

printf 'summary: %d safe authenticated probes passed; destructive/parameterized endpoints not executed\n' "$passed"
