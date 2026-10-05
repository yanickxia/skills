#!/usr/bin/env bash
set -euo pipefail

timeout=${TRILIUM_CURL_TIMEOUT:-12}
url=${TRILIUM_URL:-}
token=${TRILIUM_TOKEN:-}
run_import=${TRILIUM_VALIDATE_IMPORT:-0}
run_backup=${TRILIUM_VALIDATE_BACKUP:-0}
run_auth=${TRILIUM_PASSWORD:+1}
run_auth=${TRILIUM_VALIDATE_AUTH:-$run_auth}

tmpdir=$(mktemp -d)
created_notes=()
created_attributes=()
created_attachments=()
created_branches=()
passes=0
skips=0

cleanup() {
  set +e
  for attachment_id in "${created_attachments[@]:-}"; do
    [[ -n "$attachment_id" ]] && curl -sS --max-time 5 -o /dev/null -X DELETE "$url/etapi/attachments/$attachment_id" -H "Authorization: $token"
  done
  for attribute_id in "${created_attributes[@]:-}"; do
    [[ -n "$attribute_id" ]] && curl -sS --max-time 5 -o /dev/null -X DELETE "$url/etapi/attributes/$attribute_id" -H "Authorization: $token"
  done
  for branch_id in "${created_branches[@]:-}"; do
    [[ -n "$branch_id" ]] && curl -sS --max-time 5 -o /dev/null -X DELETE "$url/etapi/branches/$branch_id" -H "Authorization: $token"
  done
  for note_id in "${created_notes[@]:-}"; do
    [[ -n "$note_id" ]] && curl -sS --max-time 5 -o /dev/null -X DELETE "$url/etapi/notes/$note_id" -H "Authorization: $token"
  done
  rm -rf "$tmpdir"
}
trap cleanup EXIT

usage() {
  cat <<'USAGE'
Usage: TRILIUM_URL=http://localhost:37840 TRILIUM_TOKEN=... scripts/validate-live.sh

Runs a live ETAPI validation against a Trilium server.

Optional:
  TRILIUM_VALIDATE_IMPORT=1   include POST /notes/{noteId}/import
  TRILIUM_VALIDATE_BACKUP=1   include PUT /backup/{backupName}
  TRILIUM_PASSWORD=...        validate /auth/login using a temporary token
  TRILIUM_CURL_TIMEOUT=12     per-request timeout in seconds
USAGE
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'missing required command: %s\n' "$1" >&2
    exit 2
  }
}

pass() {
  passes=$((passes + 1))
  printf 'ok - %s\n' "$1"
}

skip() {
  skips=$((skips + 1))
  printf 'skip - %s (%s)\n' "$1" "$2"
}

die() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

request_to_file() {
  local method=$1 endpoint=$2 outfile=$3 body=${4:-} content_type=${5:-application/json}
  local code
  if [[ -n "$body" ]]; then
    code=$(curl -sS --fail-with-body --max-time "$timeout" -o "$outfile" -w '%{http_code}' \
      -X "$method" "$url$endpoint" \
      -H "Authorization: $token" \
      -H "Content-Type: $content_type" \
      --data-binary "$body")
  else
    code=$(curl -sS --fail-with-body --max-time "$timeout" -o "$outfile" -w '%{http_code}' \
      -X "$method" "$url$endpoint" \
      -H "Authorization: $token")
  fi
  printf '%s' "$code"
}

request_json() {
  local method=$1 endpoint=$2 body=${3:-}
  local outfile="$tmpdir/response.json"
  request_to_file "$method" "$endpoint" "$outfile" "$body" >/dev/null
  cat "$outfile"
}

expect_code() {
  local method=$1 endpoint=$2 expected=$3 body=${4:-} content_type=${5:-application/json}
  local outfile="$tmpdir/expect.out"
  local code
  code=$(request_to_file "$method" "$endpoint" "$outfile" "$body" "$content_type") || {
    cat "$outfile" >&2 2>/dev/null || true
    die "$method $endpoint failed"
  }
  [[ "$code" == "$expected" ]] || die "$method $endpoint returned $code, expected $expected: $(head -c 200 "$outfile" 2>/dev/null)"
}

detect_url() {
  [[ -n "$url" ]] && return
  local candidate code
  for candidate in http://localhost:37840 http://localhost:37740 http://localhost:8080; do
    code=$(curl -sS --max-time 3 -o /dev/null -w '%{http_code}' "$candidate/etapi/app-info" -H "Authorization: $token" 2>/dev/null || true)
    if [[ "$code" == "200" ]]; then
      url=$candidate
      return
    fi
  done
  die 'TRILIUM_URL was not set and auto-detection failed'
}

[[ ${1:-} == "-h" || ${1:-} == "--help" ]] && { usage; exit 0; }

require_cmd curl
require_cmd jq

if [[ -z "$token" && -t 0 ]]; then
  read -r -s -p 'TRILIUM_TOKEN: ' token
  printf '\n'
fi
[[ -n "$token" ]] || die 'TRILIUM_TOKEN is required'

detect_url
url=${url%/}

marker="codex-etapi-$(date +%Y%m%d%H%M%S)-$$"

app_info=$(request_json GET /etapi/app-info)
jq -e '.appVersion and .dbVersion' >/dev/null <<<"$app_info" || die 'app-info response is missing version fields'
pass 'GET /app-info'

if [[ "$run_auth" == "1" ]]; then
  [[ -n "${TRILIUM_PASSWORD:-}" ]] || die 'TRILIUM_PASSWORD is required when TRILIUM_VALIDATE_AUTH=1'
  login_body=$(jq -nc --arg password "$TRILIUM_PASSWORD" '{password:$password}')
  login_json=$(curl -sS --fail-with-body --max-time "$timeout" -X POST "$url/etapi/auth/login" \
    -H 'Content-Type: application/json' --data-binary "$login_body")
  temp_token=$(jq -r '.authToken // empty' <<<"$login_json")
  [[ -n "$temp_token" ]] || die 'POST /auth/login did not return authToken'
  pass 'POST /auth/login'
  logout_code=$(curl -sS --fail-with-body --max-time "$timeout" -o "$tmpdir/logout.out" -w '%{http_code}' \
    -X POST "$url/etapi/auth/logout" -H "Authorization: $temp_token")
  [[ "$logout_code" == "204" ]] || die "POST /auth/logout returned $logout_code"
  pass 'POST /auth/logout'
else
  skip 'POST /auth/login' 'TRILIUM_PASSWORD not set'
  skip 'POST /auth/logout' 'would invalidate the supplied token'
fi

parent_json=$(request_json POST /etapi/create-note "$(jq -nc --arg title "Codex ETAPI Parent $marker" '{parentNoteId:"root", title:$title, type:"book", content:""}')")
parent_id=$(jq -r '.note.noteId' <<<"$parent_json")
[[ -n "$parent_id" && "$parent_id" != "null" ]] || die 'parent note was not created'
created_notes=("$parent_id" "${created_notes[@]:-}")
pass 'POST /create-note parent'

second_json=$(request_json POST /etapi/create-note "$(jq -nc --arg title "Codex ETAPI Second Parent $marker" '{parentNoteId:"root", title:$title, type:"book", content:""}')")
second_parent_id=$(jq -r '.note.noteId' <<<"$second_json")
created_notes=("$second_parent_id" "${created_notes[@]:-}")
pass 'POST /create-note second parent'

child_json=$(request_json POST /etapi/create-note "$(jq -nc --arg parent "$parent_id" --arg title "Codex ETAPI Child $marker" --arg content "<p>initial $marker</p>" '{parentNoteId:$parent, title:$title, type:"text", content:$content}')")
child_id=$(jq -r '.note.noteId' <<<"$child_json")
created_notes=("$child_id" "${created_notes[@]:-}")
pass 'POST /create-note child'

request_json GET "/etapi/notes/$child_id" | jq -e --arg id "$child_id" '.noteId == $id' >/dev/null
pass 'GET /notes/{noteId}'

request_json PATCH "/etapi/notes/$child_id" "$(jq -nc --arg title "Codex ETAPI Child Renamed $marker" '{title:$title}')" | jq -e --arg marker "$marker" '.title | contains($marker)' >/dev/null
pass 'PATCH /notes/{noteId}'

expect_code PUT "/etapi/notes/$child_id/content" 204 "<p>updated $marker</p>" text/plain
pass 'PUT /notes/{noteId}/content'

content_file="$tmpdir/content.out"
request_to_file GET "/etapi/notes/$child_id/content" "$content_file" >/dev/null
grep -q "updated $marker" "$content_file" || die 'updated note content was not returned'
pass 'GET /notes/{noteId}/content'

curl -sS --fail-with-body --max-time "$timeout" -G "$url/etapi/notes" \
  -H "Authorization: $token" \
  --data-urlencode "search=$marker" \
  --data-urlencode 'limit=10' |
  jq -e --arg id "$child_id" '.results[]? | select(.noteId == $id)' >/dev/null
pass 'GET /notes'

request_json GET "/etapi/notes/history?ancestorNoteId=$parent_id" | jq -e 'type == "array"' >/dev/null
pass 'GET /notes/history'

expect_code POST "/etapi/notes/$child_id/revision?format=markdown" 204
pass 'POST /notes/{noteId}/revision'

revisions_json=$(request_json GET "/etapi/notes/$child_id/revisions")
jq -e 'type == "array"' >/dev/null <<<"$revisions_json"
pass 'GET /notes/{noteId}/revisions'
revision_id=$(jq -r '.[0].revisionId // empty' <<<"$revisions_json")
if [[ -n "$revision_id" ]]; then
  request_json GET "/etapi/revisions/$revision_id" | jq -e --arg id "$revision_id" '.revisionId == $id' >/dev/null
  pass 'GET /revisions/{revisionId}'
  request_to_file GET "/etapi/revisions/$revision_id/content" "$tmpdir/revision-content.out" >/dev/null
  pass 'GET /revisions/{revisionId}/content'
else
  skip 'GET /revisions/{revisionId}' 'no revision returned for test note'
  skip 'GET /revisions/{revisionId}/content' 'no revision returned for test note'
fi

request_json GET "/etapi/notes/$child_id/attachments" | jq -e 'type == "array"' >/dev/null
pass 'GET /notes/{noteId}/attachments'

attachment_json=$(request_json POST /etapi/attachments "$(jq -nc --arg owner "$child_id" --arg content "attachment $marker" '{ownerId:$owner, role:"file", mime:"text/plain", title:"codex-etapi.txt", content:$content, position:10}')")
attachment_id=$(jq -r '.attachmentId' <<<"$attachment_json")
created_attachments=("$attachment_id" "${created_attachments[@]:-}")
pass 'POST /attachments'

request_json GET "/etapi/attachments/$attachment_id" | jq -e --arg id "$attachment_id" '.attachmentId == $id' >/dev/null
pass 'GET /attachments/{attachmentId}'

request_json PATCH "/etapi/attachments/$attachment_id" '{"role":"file","mime":"text/plain","title":"codex-etapi-renamed.txt","position":20}' | jq -e '.title == "codex-etapi-renamed.txt" and .position == 20' >/dev/null
pass 'PATCH /attachments/{attachmentId}'

request_to_file GET "/etapi/attachments/$attachment_id/content" "$tmpdir/attachment.out" >/dev/null
grep -q "attachment $marker" "$tmpdir/attachment.out" || die 'attachment content was not returned'
pass 'GET /attachments/{attachmentId}/content'

expect_code PUT "/etapi/attachments/$attachment_id/content" 204 "attachment patched $marker" text/plain
pass 'PUT /attachments/{attachmentId}/content'

attribute_json=$(request_json POST /etapi/attributes "$(jq -nc --arg note "$child_id" --arg value "$marker" '{noteId:$note,type:"label",name:"codexEtapiTest",value:$value,isInheritable:false,position:10}')")
attribute_id=$(jq -r '.attributeId' <<<"$attribute_json")
created_attributes=("$attribute_id" "${created_attributes[@]:-}")
pass 'POST /attributes'

request_json GET "/etapi/attributes/$attribute_id" | jq -e --arg id "$attribute_id" '.attributeId == $id' >/dev/null
pass 'GET /attributes/{attributeId}'

request_json PATCH "/etapi/attributes/$attribute_id" '{"value":"patched","position":20}' | jq -e '.value == "patched" and .position == 20' >/dev/null
pass 'PATCH /attributes/{attributeId}'

branch_json=$(request_json POST /etapi/branches "$(jq -nc --arg note "$child_id" --arg parent "$second_parent_id" '{noteId:$note,parentNoteId:$parent,prefix:"clone",notePosition:100,isExpanded:false}')")
branch_id=$(jq -r '.branchId' <<<"$branch_json")
created_branches=("$branch_id" "${created_branches[@]:-}")
pass 'POST /branches'

request_json GET "/etapi/branches/$branch_id" | jq -e --arg id "$branch_id" '.branchId == $id' >/dev/null
pass 'GET /branches/{branchId}'

request_json PATCH "/etapi/branches/$branch_id" '{"prefix":"moved","notePosition":110}' | jq -e '.prefix == "moved" and .notePosition == 110' >/dev/null
pass 'PATCH /branches/{branchId}'

expect_code POST "/etapi/refresh-note-ordering/$second_parent_id" 204
pass 'POST /refresh-note-ordering/{parentNoteId}'

curl -sS --fail-with-body --max-time "$timeout" "$url/etapi/notes/$child_id/export?format=markdown" -H "Authorization: $token" -o "$tmpdir/export-markdown.zip"
[[ -s "$tmpdir/export-markdown.zip" ]] || die 'markdown export was empty'
pass 'GET /notes/{noteId}/export markdown'

curl -sS --fail-with-body --max-time "$timeout" "$url/etapi/notes/$child_id/export?format=html" -H "Authorization: $token" -o "$tmpdir/export-html.zip"
[[ -s "$tmpdir/export-html.zip" ]] || die 'html export was empty'
pass 'GET /notes/{noteId}/export html'

if [[ "$run_import" == "1" ]]; then
  import_out="$tmpdir/import.out"
  import_err="$tmpdir/import.err"
  : > "$import_out"
  : > "$import_err"
  import_code=$(curl -sS --max-time "$timeout" -o "$import_out" -w '%{http_code}' -X POST "$url/etapi/notes/$parent_id/import" \
    -H "Authorization: $token" -H 'Content-Type: application/zip' --data-binary "@$tmpdir/export-markdown.zip" 2>"$import_err" || true)
  [[ "$import_code" == "201" ]] || die "POST /notes/{noteId}/import returned $import_code: $(head -c 200 "$import_err" "$import_out" 2>/dev/null)"
  imported_id=$(jq -r '.note.noteId' "$import_out")
  created_notes=("$imported_id" "${created_notes[@]:-}")
  pass 'POST /notes/{noteId}/import'
else
  skip 'POST /notes/{noteId}/import' 'set TRILIUM_VALIDATE_IMPORT=1 to include; local 0.103.0 currently times out'
fi

today=$(date +%F)
request_json GET "/etapi/inbox/$today" | jq -e '.noteId' >/dev/null
pass 'GET /inbox/{date}'

request_json GET "/etapi/calendar/days/$today" | jq -e '.noteId' >/dev/null
pass 'GET /calendar/days/{date}'

week=$(date +%G-W%V)
week_out="$tmpdir/week-note.json"
week_code=$(curl -sS --max-time "$timeout" -o "$week_out" -w '%{http_code}' "$url/etapi/calendar/weeks/$week" -H "Authorization: $token" || true)
if [[ "$week_code" == "200" ]]; then
  jq -e '.noteId' "$week_out" >/dev/null
  pass 'GET /calendar/weeks/{week}'
elif jq -e '.code == "WEEK_NOT_FOUND" or .code == "WEEK_INVALID"' "$week_out" >/dev/null 2>&1; then
  skip 'GET /calendar/weeks/{week}' "$(jq -r '.code' "$week_out")"
else
  die "GET /calendar/weeks/{week} returned $week_code: $(head -c 200 "$week_out")"
fi

month=$(date +%Y-%m)
request_json GET "/etapi/calendar/months/$month" | jq -e '.noteId' >/dev/null
pass 'GET /calendar/months/{month}'

year=$(date +%Y)
request_json GET "/etapi/calendar/years/$year" | jq -e '.noteId' >/dev/null
pass 'GET /calendar/years/{year}'

deleted_json=$(request_json POST /etapi/create-note "$(jq -nc --arg parent "$parent_id" --arg title "Codex ETAPI Undelete $marker" '{parentNoteId:$parent, title:$title, type:"text", content:"<p>deleted</p>"}')")
deleted_note_id=$(jq -r '.note.noteId' <<<"$deleted_json")
expect_code DELETE "/etapi/notes/$deleted_note_id" 204
pass 'DELETE /notes/{noteId}'
undelete_json=$(request_json POST "/etapi/notes/$deleted_note_id/undelete")
jq -e --arg id "$deleted_note_id" '.success == true or .note.noteId == $id or .noteId == $id' >/dev/null <<<"$undelete_json"
created_notes=("$deleted_note_id" "${created_notes[@]:-}")
pass 'POST /notes/{noteId}/undelete'

expect_code DELETE "/etapi/branches/$branch_id" 204
created_branches=()
pass 'DELETE /branches/{branchId}'

expect_code DELETE "/etapi/attributes/$attribute_id" 204
created_attributes=()
pass 'DELETE /attributes/{attributeId}'

expect_code DELETE "/etapi/attachments/$attachment_id" 204
created_attachments=()
pass 'DELETE /attachments/{attachmentId}'

if [[ "$run_backup" == "1" ]]; then
  backup_name="codex_${marker//-/}"
  backup_name=${backup_name:0:32}
  expect_code PUT "/etapi/backup/$backup_name" 204
  pass 'PUT /backup/{backupName}'
else
  skip 'PUT /backup/{backupName}' 'set TRILIUM_VALIDATE_BACKUP=1 to create a server-side backup file'
fi

printf 'summary: %d passed, %d skipped\n' "$passes" "$skips"
