---
name: youcom-search
description: Web search and URL content extraction via the You.com API - cited web results and full-page text retrieval for up to 10 URLs per call. Use when the user needs current web information with citations, or wants to read the full content of specific web pages (scrape a page, fetch article text, extract URL content). Triggers on You.com search, extract page content, fetch URL text, or read a web page.
---

# You.com Search & Contents

## Overview

The You.com API exposes a small family of `POST` endpoints: `search` returns ranked, cited web results; `contents` extracts the readable text of specific URLs; `research` runs a multi-source research pass. Every request is `POST` with a JSON body and the same two headers, so it composes well with `curl` and `jq`.

**Core concepts:**
- **Cited results** — `search` returns hits with citations, so answers can point back to sources
- **Bearer auth** — authentication is `Authorization: Bearer $YDC_API_KEY` (not a query parameter)
- **Batch extraction** — `contents` resolves up to **10 URLs per call** and returns each page's extracted text
- **Freshness window** — `freshness` filters `search` by age (`day` / `week` / `month` / `year`)

## When to Use

- Fetch current information that postdates the model's training data, **with citations**
- Fact-check or source a claim against live web pages
- Read the full body of specific pages (scrape a page, fetch article text, extract URL content)
- Turn a search result list into full text with the search → contents workflow
- Feed fresh, sourced context into a summary or RAG pipeline

**Do not use** when you only need a snippet — `search` already returns titles, URLs, and snippets. Reach for `contents` only when you need the full page text.

## Setup

All examples below assume:

```bash
export YDC_API_KEY="<from https://you.com/platform/api-keys>"
export YOU_API_BASE_URL="${YOU_API_BASE_URL:-https://api.you.com}"
```

Direct connection uses the official base URL `https://api.you.com`. Override `YOU_API_BASE_URL` to route through a self-hosted gateway (see [Custom Gateway](#custom-gateway-base-url-override)).

Every request needs two headers:

```bash
-H "Authorization: Bearer $YDC_API_KEY"
-H "Content-Type: application/json"
```

All three endpoints are `POST` with a JSON body — there is no `GET` form.

## Quick Reference

| Operation | Method | Path | Body |
|-----------|--------|------|------|
| Search | POST | `/api/search` | `{"query": "...", "count": 10, "freshness": "week"}` |
| Contents | POST | `/api/contents` | `{"urls": ["https://...", "https://..."]}` |
| Research | POST | `/api/research` | `{"query": "..."}` |

- **Search**: `count` is `1`–`20`; `freshness` is optional and accepts `day` / `week` / `month` / `year`.
- **Contents**: up to **10 URLs** per call.
- **Research**: pass a `query` and get a synthesized research report (details in [api-reference.md](api-reference.md)).

Full endpoint, parameter, and response-schema reference: [api-reference.md](api-reference.md).

## Custom Gateway (Base URL Override)

Point `YOU_API_BASE_URL` at a self-hosted gateway (for example an `ai-proxy` search adapter) when you do not want to call You.com directly — for example to centralize quota, cache results, or hide the upstream key:

```bash
export YOU_API_BASE_URL="http://localhost:3051/you"
export YDC_API_KEY="<gateway inbound key>"
```

In this mode:
- `YDC_API_KEY` is the **gateway's inbound key**, not necessarily the You.com key.
- The **real upstream key is injected by the gateway** server-side; callers never see it.
- The gateway must map `/api/search`, `/api/contents`, and `/api/research` onto the upstream You.com API. Requests keep the same JSON body and `Authorization: Bearer ...` + `Content-Type: application/json` headers.

The examples below are unchanged between direct and gateway modes — only the base URL and the value of the key differ.

## Core Patterns (curl + jq)

All snippets below assume `YOU_API_BASE_URL` and `YDC_API_KEY` are exported.

### 1. Basic search

```bash
curl -s -X POST "$YOU_API_BASE_URL/api/search" \
  -H "Authorization: Bearer $YDC_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query":"you.com search api","count":10}' | jq
```

Extract a compact result list (adjust field names to the actual response):

```bash
curl -s -X POST "$YOU_API_BASE_URL/api/search" \
  -H "Authorization: Bearer $YDC_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query":"chezmoi dotfiles","count":5}' \
  | jq '.results[] | {title, url}'
```

### 2. News-style search with a freshness filter

Use `freshness: "week"` for news or recent releases; `day` / `month` / `year` are also accepted:

```bash
curl -s -X POST "$YOU_API_BASE_URL/api/search" \
  -H "Authorization: Bearer $YDC_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query":"AI regulation news","count":10,"freshness":"week"}' | jq
```

### 3. Extract full page content for a batch of URLs

```bash
curl -s -X POST "$YOU_API_BASE_URL/api/contents" \
  -H "Authorization: Bearer $YDC_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"urls":["https://example.com/a","https://example.com/b"]}' | jq
```

`contents` responds with a `results` array, one entry per URL, each carrying the URL and the extracted page text. Field names can vary, so inspect them when unsure:

```bash
# Explore the shape of each result
curl -s -X POST "$YOU_API_BASE_URL/api/contents" \
  -H "Authorization: Bearer $YDC_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"urls":["https://example.com/a"]}' \
  | jq '.results[] | keys'

# Then pull the fields you want (name the text field seen above)
curl -s -X POST "$YOU_API_BASE_URL/api/contents" \
  -H "Authorization: Bearer $YDC_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"urls":["https://example.com/a","https://example.com/b"]}' \
  | jq '.results[] | {url, text}'
```

### 4. Research report (one-liner)

```bash
curl -s -X POST "$YOU_API_BASE_URL/api/research" \
  -H "Authorization: Bearer $YDC_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query":"state of WebGPU support in 2025"}' | jq
```

### Typical workflow: search → contents

This is the core combination of the skill:

1. **Search** to get a ranked list of candidate URLs:
   ```bash
   curl -s -X POST "$YOU_API_BASE_URL/api/search" \
     -H "Authorization: Bearer $YDC_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"query":"rust 1.80 release notes","count":10}' | jq -r '.results[].url'
   ```
2. **Feed those URLs into `contents`** (at most **10 per call**) to pull the full text:
   ```bash
   curl -s -X POST "$YOU_API_BASE_URL/api/contents" \
     -H "Authorization: Bearer $YDC_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"urls":["https://blog.rust-lang.org/2024/07/25/Rust-1.80.0.html","https://doc.rust-lang.org/stable/releases.html"]}' | jq
   ```
3. If you have more than 10 URLs, **chunk the list** into batches of ≤10 and concatenate the results.

## Error Handling

| Code | Meaning | Action |
|------|---------|--------|
| 401 | Missing or invalid API key | Set `YDC_API_KEY`; re-issue the key if it was revoked |
| 402 | Payment required / out of quota | Check the You.com plan or gateway quota |
| 429 | Rate limited | Back off and retry |
| 5xx / network error | Upstream or connectivity failure | Retry with backoff; verify `YOU_API_BASE_URL` is reachable |

The most common failure is a missing key. If `YDC_API_KEY` is unset the request is unauthenticated:

```bash
[ -n "${YDC_API_KEY:-}" ] || echo 'set YDC_API_KEY first: export YDC_API_KEY="<from https://you.com/platform/api-keys>"'
```

Inspect the raw error body when a request fails:

```bash
curl -s -X POST "$YOU_API_BASE_URL/api/search" \
  -H "Authorization: Bearer $YDC_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query":"test","count":10}' | jq
```

## Validation

Run the static checks before publishing or after editing examples:

```bash
youcom-search/tests/static-validation.sh
```

The script verifies the `Makefile` metadata, the required environment variables and endpoints in `SKILL.md`, and the presence of the research endpoint in `api-reference.md`. It performs no network calls and needs no API key.