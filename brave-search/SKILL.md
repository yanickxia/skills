---
name: brave-search
description: Search the web via the Brave Search API - web results, news, images, and videos with freshness, language, and safe-search filters. Use when the user needs current information beyond training data, fact-checking, recent news or releases, or localized web results. Triggers on web search, search the internet, latest news, or finding up-to-date information.
---

# Brave Search

## Overview

Brave Search is a REST API over the Brave independent web index. It returns ranked web pages, news, images, videos, and suggestions. All endpoints are plain `GET` requests with query parameters, so they compose well with `curl` and `jq`.

**Core concepts:**
- **Result set** — each endpoint groups its hits under a typed key: `.web.results`, `.news.results`, `.images.results`, `.videos.results`
- **Subscription token** — authentication is the `X-Subscription-Token` header, not `Authorization`
- **Freshness window** — `freshness` filters by age (`pd`, `pw`, `pm`, `py`, or a `YYYY-MM-DDtoYYYY-MM-DD` range)
- **Market** — `country` (2-letter code) plus `search_lang` localize ranking and results

## When to Use

- Fetch current information that postdates the model's training data
- Fact-check or source a claim against live web pages
- Track recent news, releases, or changelogs (`freshness=pd`/`pw`)
- Find localized results for a specific country or language
- Feed fresh context into a summary or RAG pipeline

**Do not use** to scrape page bodies — this API returns titles, URLs, and snippets, not full text. Fetch the result URL directly when you need the article.

## Setup

All examples below assume:

```bash
export BRAVE_SEARCH_API_KEY="<from https://api-dashboard.search.brave.com/register>"  # Free AI tier
export BRAVE_SEARCH_BASE_URL="${BRAVE_SEARCH_BASE_URL:-https://api.search.brave.com}"
```

Direct connection uses the official base URL `https://api.search.brave.com`. Override `BRAVE_SEARCH_BASE_URL` to route through a self-hosted gateway (see [Custom Gateway](#custom-gateway-base-url-override)).

Every request needs two headers:

```bash
-H "Accept: application/json"
-H "X-Subscription-Token: $BRAVE_SEARCH_API_KEY"
```

## Quick Reference

| Operation | Method | Path |
|-----------|--------|------|
| Web search | GET | `/res/v1/web/search` |
| News search | GET | `/res/v1/news/search` |
| Image search | GET | `/res/v1/images/search` |
| Video search | GET | `/res/v1/videos/search` |
| Autocomplete | GET | `/res/v1/suggest/search` |
| Spell check | GET | `/res/v1/spellcheck/search` |

Full endpoint, parameter, and response-schema reference: [api-reference.md](api-reference.md).

## Custom Gateway (Base URL Override)

Point `BRAVE_SEARCH_BASE_URL` at a self-hosted gateway (for example an `ai-proxy` search adapter) when you do not want to call Brave directly — for example to centralize quota, cache results, or hide the upstream key:

```bash
export BRAVE_SEARCH_BASE_URL="http://localhost:3051/brave"
export BRAVE_SEARCH_API_KEY="<gateway inbound key>"
```

In this mode:
- `BRAVE_SEARCH_API_KEY` is the **gateway's inbound key**, not the Brave subscription token.
- The **real upstream key is injected by the gateway** server-side; callers never see it.
- The gateway must map the official paths (`/res/v1/web/search`, `/res/v1/news/search`, ...) onto the upstream Brave API. Requests keep the same query parameters and `Accept: application/json` header.

The examples below are unchanged between direct and gateway modes — only the base URL and the value of the key differ.

## Core Patterns (curl + jq)

All snippets below assume `BRAVE_SEARCH_BASE_URL` and `BRAVE_SEARCH_API_KEY` are exported.

### Web Search parameters

| Param | Notes |
|-------|-------|
| `q` | Required query string. For complex queries use `POST` with a JSON body: `{"query": "..."}` |
| `count` | Number of results, `1`–`20` (default 20) |
| `country` | 2-letter country code, e.g. `US`, `CN` |
| `search_lang` | Result language, e.g. `en`, `zh-hans` |
| `freshness` | `pd` (24h) / `pw` (7d) / `pm` (31d) / `py` (365d) / `YYYY-MM-DDtoYYYY-MM-DD` |
| `safesearch` | `off` / `moderate` / `strict` |
| `offset` | Pagination offset, `0`–`9` |

### 1. Basic web search

```bash
curl -s "$BRAVE_SEARCH_BASE_URL/res/v1/web/search?q=brave+search+api" \
  -H "Accept: application/json" \
  -H "X-Subscription-Token: $BRAVE_SEARCH_API_KEY" | jq
```

### 2. Web search with filters

Use `--data-urlencode` so `q` and every other value are encoded safely:

```bash
curl -sG "$BRAVE_SEARCH_BASE_URL/res/v1/web/search" \
  -H "Accept: application/json" \
  -H "X-Subscription-Token: $BRAVE_SEARCH_API_KEY" \
  --data-urlencode 'q=rust 1.80 release notes' \
  --data-urlencode 'country=US' \
  --data-urlencode 'search_lang=en' \
  --data-urlencode 'freshness=pw' \
  --data-urlencode 'count=10' \
  --data-urlencode 'safesearch=moderate' | jq
```

### 3. News search

```bash
curl -sG "$BRAVE_SEARCH_BASE_URL/res/v1/news/search" \
  -H "Accept: application/json" \
  -H "X-Subscription-Token: $BRAVE_SEARCH_API_KEY" \
  --data-urlencode 'q=AI regulation' \
  --data-urlencode 'freshness=pw' \
  --data-urlencode 'count=20' | jq
```

### 4. Extract a compact result list

```bash
# Web results
curl -sG "$BRAVE_SEARCH_BASE_URL/res/v1/web/search" \
  -H "Accept: application/json" \
  -H "X-Subscription-Token: $BRAVE_SEARCH_API_KEY" \
  --data-urlencode 'q=chezmoi dotfiles' \
  --data-urlencode 'count=5' | jq '.web.results[] | {title, url, age}'

# News results
curl -sG "$BRAVE_SEARCH_BASE_URL/res/v1/news/search" \
  -H "Accept: application/json" \
  -H "X-Subscription-Token: $BRAVE_SEARCH_API_KEY" \
  --data-urlencode 'q=macOS Sequoia' \
  --data-urlencode 'freshness=pw' | jq '.news.results[] | {title, url, age}'
```

## Error Handling

Error responses are JSON with details under `.errors`:

```bash
curl -sG "$BRAVE_SEARCH_BASE_URL/res/v1/web/search" \
  -H "Accept: application/json" \
  -H "X-Subscription-Token: $BRAVE_SEARCH_API_KEY" \
  --data-urlencode 'q=test' | jq '.errors'
```

| Code | Meaning | Action |
|------|---------|--------|
| 401 | Missing, invalid, or expired API key | Check `X-Subscription-Token`; re-issue the key |
| 422 | Invalid query parameter (bad enum, out-of-range `count`/`offset`) | Fix the offending parameter |
| 429 | Rate limited or quota exceeded | Back off exponentially and retry |

Retry example with exponential backoff:

```bash
for delay in 1 2 4 8; do
  curl -s -o /tmp/brave.json -w '%{http_code}' -G "$BRAVE_SEARCH_BASE_URL/res/v1/web/search" \
    -H "Accept: application/json" \
    -H "X-Subscription-Token: $BRAVE_SEARCH_API_KEY" \
    --data-urlencode 'q=test' | grep -q '^200$' && break
  sleep "$delay"
done
jq '.web.results[] | {title, url}' /tmp/brave.json
```

## Common Pitfalls

- **Auth is `X-Subscription-Token`, not `Authorization: Bearer`.** Using the wrong header returns 401.
- **`q` is required.** Omitting it returns 422, not an empty result set.
- **`count` is capped at 20 and `offset` at 9.** Larger values are rejected.
- **`freshness` accepts only the enum values or an explicit date range.** Free-form strings fail validation.
- **`country` is a 2-letter code, `search_lang` is a language tag** (e.g. `zh-hans`). They are different axes; set both to localize properly.
- **Results live under a typed key**, not a flat array — read `.web.results`, `.news.results`, etc.
- **The API returns snippets, not article bodies.** Follow `url` for full content.

## Validation

Run the static checks before publishing or after editing examples:

```bash
brave-search/tests/static-validation.sh
```

The script verifies the `Makefile` metadata, the required environment variables and header in `SKILL.md`, and the presence of the news and images endpoints in `api-reference.md`. It performs no network calls and needs no API key.