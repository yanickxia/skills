#!/usr/bin/env bash
set -euo pipefail

kind=etapi
url=
timeout=${TRILIUM_DOCS_TIMEOUT:-60}

usage() {
  cat <<'USAGE'
Usage: scripts/list-api-endpoints.sh [--kind etapi|internal] [--url URL]

Fetch a Trilium Redoc API page and print unique "METHOD /path" entries.
Defaults to the official ETAPI reference.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --kind)
      kind=${2:-}
      shift 2
      ;;
    --url)
      url=${2:-}
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$url" ]]; then
  case "$kind" in
    etapi) url='https://docs.triliumnotes.org/rest-api/etapi/' ;;
    internal) url='https://docs.triliumnotes.org/rest-api/internal/' ;;
    *)
      printf 'invalid --kind: %s\n' "$kind" >&2
      exit 2
      ;;
  esac
fi

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

curl -fsSL --compressed --max-time "$timeout" "$url" -o "$tmp"

perl -0777 -ne 'while (/<span type="(get|post|put|patch|delete)"[^>]*>[^<]*<\/span><span class="[^"]+">([^<]+)<\/span>/g) { print uc($1), " ", $2, "\n" }' "$tmp" |
  sort -u
