---
name: serpapi-search
description: Search 100+ engines (Google, Bing, Baidu, YouTube, DuckDuckGo, and more) via the SerpApi REST API with structured JSON results. Use when the user needs SERP data - organic results, answer boxes, related questions, localized searches - or engine-specific results like Baidu or YouTube metadata. Triggers on search Google, Baidu search, Bing search, YouTube search, SERP data, or structured search engine results.
---

# SerpApi Search

## Overview

SerpApi is a hosted REST API that scrapes search engine result pages (SERPs) and returns them as structured JSON. One endpoint shape covers 100+ engines: you set `engine` to pick the backend, pass engine-specific query parameters, and read a normalized response (`organic_results`, `answer_box`, `related_questions`, ...).

**Core concepts:**
- **Engine** — the backend being scraped (`google`, `bing`, `baidu`, `duckduckgo`, `youtube`, ...), selected with the `engine` parameter
- **Query** — usually `q`, but some engines use a different parameter (YouTube uses `search_query`, Baidu uses `q` with `pn` for paging)
- **Auth** — a single `api_key` query parameter, not a header
- **Billing** — each successful search consumes one credit from your plan; check `/account.json`

## When to Use

- Fetch Google/Bing/Baidu/DuckDuckGo organic results as JSON for an agent or script
- Pull answer boxes, knowledge graph, related questions, or top stories
- Run localized searches (`location`, `hl`, `gl`) for a specific country/language
- Get engine-specific data: Baidu Chinese results, YouTube video metadata, and similar
- Scrape SERPs without writing or maintaining a browser scraper

**Do not use** for pages that are not search results — SerpApi is SERP-shaped. For arbitrary page scraping, use a general fetch/browser tool instead.

## Setup

All examples below assume:

```bash
export SERPAPI_API_KEY="<from https://serpapi.com/manage-api-key>"
export SERPAPI_BASE_URL="${SERPAPI_BASE_URL:-https://serpapi.com}"
```

`SERPAPI_BASE_URL` defaults to the official host but can be overridden — see [Custom Gateway](#custom-gateway-base-url-override) below.

The key travels as the `api_key` **query parameter** (not a header). Never commit a request URL that contains the key, and never paste one into logs, issues, or chat — a full URL with `api_key=...` is a live credential.

## Quick Reference

| Operation | Method | Path |
|-----------|--------|------|
| Search (any engine) | GET | `$SERPAPI_BASE_URL/search.json` |
| Account status / credits | GET | `$SERPAPI_BASE_URL/account.json` |

**Parameters** (`/search.json`):

| Parameter | Required | Notes |
|-----------|----------|-------|
| `engine` | yes | Backend to scrape (see table below) |
| `q` | yes* | Query text (*YouTube uses `search_query`) |
| `api_key` | yes | Your SerpApi key |
| `location` | no | Geo-target, e.g. `Austin, Texas` |
| `num` | no | Results to return (Google, ≤ 100) |
| `hl` | no | UI/interface language, e.g. `en`, `zh-cn` |
| `gl` | no | Country code, e.g. `us`, `cn` |
| `device` | no | `desktop` \| `mobile` \| `tablet` |
| `safe` | no | SafeSearch, e.g. `active` \| `off` |

**Common engines:**

| engine | Query param | Notes |
|--------|-------------|-------|
| `google` | `q` | Default; supports `location`, `hl`, `gl`, `num` |
| `google_light` | `q` | Faster/cheaper Google variant, fewer extras |
| `bing` | `q` | Supports `cc` (country) |
| `baidu` | `q` | Baidu results; `pn` pages through results |
| `duckduckgo` | `q` | Privacy-focused index |
| `youtube` | `search_query` | Video results with metadata |
| `baidu_zhcn` | verify | Chinese-locale Baidu variant — confirm against current docs |

Full parameter and engine reference: [api-reference.md](api-reference.md).

## Custom Gateway (Base URL Override)

`SERPAPI_BASE_URL` lets you route through a self-hosted gateway instead of calling SerpApi directly — useful for a private proxy that injects, rotates, or hides the upstream key (e.g. an `ai-proxy` search adapter).

```bash
export SERPAPI_BASE_URL="http://localhost:3051/serp"
```

Requirements on the gateway side:

- **Path mapping** — the client still appends `/search.json` and `/account.json`, so the gateway must map `$SERPAPI_BASE_URL/search.json` to its upstream `search.json` (and likewise for `account.json`).
- **Key translation** — accept the inbound key however it arrives (query parameter or header) and forward it to the upstream as the `api_key` query parameter.
- **Response passthrough** — return the upstream JSON unchanged so the `jq` extractions below keep working.

The curl examples below are unchanged whether you point at the official host or a gateway, because everything derives from `$SERPAPI_BASE_URL`.

## Core Patterns (curl + jq)

All snippets assume `SERPAPI_API_KEY` and `SERPAPI_BASE_URL` are exported. Use `curl -G --data-urlencode` to build the query string — it handles spaces, unicode, and special characters safely.

### 1. Basic Google search

```bash
curl -sG "$SERPAPI_BASE_URL/search.json" \
  --data-urlencode "engine=google" \
  --data-urlencode "q=best coffee grinder" \
  --data-urlencode "api_key=$SERPAPI_API_KEY" | jq
```

### 2. Baidu engine (multi-engine)

```bash
curl -sG "$SERPAPI_BASE_URL/search.json" \
  --data-urlencode "engine=baidu" \
  --data-urlencode "q=咖啡研磨机" \
  --data-urlencode "api_key=$SERPAPI_API_KEY" \
  | jq '.organic_results[] | {title, link, snippet}'
```

### 3. YouTube engine

YouTube uses `search_query` instead of `q`:

```bash
curl -sG "$SERPAPI_BASE_URL/search.json" \
  --data-urlencode "engine=youtube" \
  --data-urlencode "search_query=rust async tutorial" \
  --data-urlencode "api_key=$SERPAPI_API_KEY" \
  | jq '.video_results[]? // .organic_results[]? | {title, link}'
```

### 4. Extract structured fields with jq

The response shape is engine-dependent, but these fields are common across most engines:

```bash
curl -sG "$SERPAPI_BASE_URL/search.json" \
  --data-urlencode "engine=google" \
  --data-urlencode "q=what is chezmoi" \
  --data-urlencode "api_key=$SERPAPI_API_KEY" \
  | jq '{organic: [.organic_results[] | {title, link, snippet}], answer_box, related_questions: [.related_questions[]? | .question]}'
```

Check remaining credits at any time:

```bash
curl -sG "$SERPAPI_BASE_URL/account.json" \
  --data-urlencode "api_key=$SERPAPI_API_KEY" \
  | jq '{plan: .plan_name, left: .plan_searches_left}'
```

## Error Handling

| Symptom | Cause | Fix |
|---------|-------|-----|
| HTTP `401` | Missing, malformed, or invalid `api_key` | Re-check the key from https://serpapi.com/manage-api-key |
| HTTP `429` | Rate limited / too many requests per second | Back off and retry; slow down parallel calls |
| `{"error": "..."}` in a 200 body | API-level error, e.g. `Your searches for the month have run out` | Inspect `.error`; check `/account.json` for `plan_searches_left` |

A response can be HTTP 200 yet still be an error — always branch on the presence of the `.error` field, not on the status code alone:

```bash
resp=$(curl -sG "$SERPAPI_BASE_URL/search.json" \
  --data-urlencode "engine=google" \
  --data-urlencode "q=test" \
  --data-urlencode "api_key=$SERPAPI_API_KEY")
echo "$resp" | jq -e 'has("error")' >/dev/null && echo "$resp" | jq -r .error
```

`GET $SERPAPI_BASE_URL/account.json` is the first stop for triage: it reveals the plan and remaining searches, which disambiguates quota errors from auth errors.

## Validation

Use the bundled static validator before publishing or after editing examples:

```bash
bash skills/search/serpapi-search/tests/static-validation.sh
```

It checks the Makefile `SKILL_DIR`, that `SKILL.md` documents `SERPAPI_API_KEY`, `SERPAPI_BASE_URL`, `search.json`, `api_key`, and `serpapi.com`, and that `api-reference.md` covers `organic_results` and `account.json`.

## When You Need More

- Full parameter, engine, and response-shape reference → [api-reference.md](api-reference.md)
- Officially supported engines: https://serpapi.com/search-api
- Manage your API key: https://serpapi.com/manage-api-key
