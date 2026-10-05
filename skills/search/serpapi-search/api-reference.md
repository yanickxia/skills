# SerpApi Search — API Reference

Base URL: `$SERPAPI_BASE_URL` (defaults to `https://serpapi.com`; can point at a self-hosted gateway).

Two endpoints are covered here:

- `GET /search.json` — run a search and return structured SERP JSON
- `GET /account.json` — account status and remaining credits

All parameters are passed as query-string values. The API key is a **query parameter** (`api_key`), not a header.

## `/search.json` Parameters

### Required

| Parameter | Type | Description |
|-----------|------|-------------|
| `engine` | string | Backend engine to scrape (e.g. `google`, `bing`, `baidu`). See the engine table below. |
| `q` | string | Query text. Required for most engines; **YouTube uses `search_query` instead**. |
| `api_key` | string | SerpApi key. Travels in the query string. |

### Common optional

| Parameter | Type | Description |
|-----------|------|-------------|
| `location` | string | Geo-target for the search, e.g. `Austin, Texas, United States`. |
| `num` | integer | Number of results to return. Max `100` (Google and Google-family engines). |
| `hl` | string | Interface language, e.g. `en`, `zh-cn`, `de`. |
| `gl` | string | Country/region code for results, e.g. `us`, `cn`, `gb`. |
| `device` | string | `desktop` \| `mobile` \| `tablet`. Affects layout-driven result fields. |
| `safe` | string | SafeSearch, e.g. `active` \| `off`. |
| `start` / `pn` | integer | Offset/paging, engine-dependent (Google uses `start`, Baidu uses `pn`). |
| `google_domain` | string | Google domain variant, e.g. `google.com`, `google.com.hk`. |

Not every engine honors every parameter — unsupported parameters are ignored, and the same field may come back under different keys depending on the engine.

## Engine Differences

| engine | Query param | Key extras | Paging |
|--------|-------------|------------|--------|
| `google` | `q` | `location`, `hl`, `gl`, `num`, `google_domain` | `start` |
| `google_light` | `q` | Lightweight Google payload; limited extras | `start` |
| `bing` | `q` | `cc` (country code), `hl` | `first` |
| `baidu` | `q` | Chinese-locale results | `pn` |
| `duckduckgo` | `q` | Privacy-focused index; minimal extras | `s` / `dc` |
| `youtube` | `search_query` | Video results with channel/views metadata | `sp` |
| `baidu_zhcn` | verify | Chinese-locale Baidu variant — confirm against current docs | verify |

All other engines follow the same `/search.json` shape: set `engine`, supply that engine's query parameter, and read the normalized response fields.

## `/search.json` Response Shape

Top-level keys are engine-dependent, but the following are common across most engines.

### `search_metadata`

Information about the request itself.

| Field | Description |
|-------|-------------|
| `id` | Unique search ID (useful for support/debugging) |
| `status` | e.g. `Success`, `Error` |
| `created_at` | Timestamp the search ran |
| `total_time_taken` | Server-side duration in seconds |

### `organic_results[]`

The main result list. Common fields:

| Field | Description |
|-------|-------------|
| `position` | 1-based rank in the list |
| `title` | Result title |
| `link` | Destination URL |
| `snippet` | Text preview |
| `displayed_link` | Human-readable URL as shown on the SERP |
| `source` | Site/source label (when present) |

### `answer_box`

Present when the engine surfaces a direct answer. Shape varies: may be an object with `answer`, `snippet`, `title`, `link`, or an engine-specific variant (e.g. a weather or calculator widget).

### `related_questions[]`

People-also-ask style suggestions. Each entry commonly has:

| Field | Description |
|-------|-------------|
| `question` | The suggested question |
| `snippet` | Preview answer (when returned) |
| `link` | Source URL (when returned) |
| `next_page_token` | Token to expand the question (when available) |

### `pagination`

Paging links for the current query.

| Field | Description |
|-------|-------------|
| `current` | Current page number |
| `next` | URL for the next page |
| `other_pages` | Map of page number → URL |

Other blocks (`knowledge_graph`, `top_stories`, `local_results`, `shopping_results`, `video_results`, ...) appear depending on engine and query.

## `/account.json` Response

| Field | Description |
|-------|-------------|
| `account_email` | Email on the account |
| `plan_id` | Internal plan identifier |
| `plan_name` | Plan label, e.g. `Free`, `Developer` |
| `plan_searches_left` | Searches remaining this billing period |
| `plan_searches_limit` | Total searches allowed this period |
| `total_searches_left` | Combined remaining searches |
| `this_month_usage` | Searches used this month |
| `extra_credits` | Purchased add-on credits |

```bash
curl -sG "$SERPAPI_BASE_URL/account.json" \
  --data-urlencode "api_key=$SERPAPI_API_KEY" \
  | jq '{plan: .plan_name, left: .plan_searches_left}'
```

## Errors

| Status | Meaning | Notes |
|--------|---------|-------|
| `200` | Success | May still contain an `.error` field — always check it |
| `401` | Unauthorized | `api_key` missing or invalid |
| `429` | Too many requests | Rate limited; back off before retrying |

Error bodies carry an `error` string, for example:

```
Your searches for the month have run out
```

When triaging, call `/account.json` first: it distinguishes an exhausted quota from a bad key.

## Examples

Basic Google search:

```bash
curl -sG "$SERPAPI_BASE_URL/search.json" \
  --data-urlencode "engine=google" \
  --data-urlencode "q=best coffee grinder" \
  --data-urlencode "api_key=$SERPAPI_API_KEY" | jq
```

Localized Baidu search:

```bash
curl -sG "$SERPAPI_BASE_URL/search.json" \
  --data-urlencode "engine=baidu" \
  --data-urlencode "q=咖啡研磨机" \
  --data-urlencode "api_key=$SERPAPI_API_KEY" | jq '.organic_results'
```

YouTube search (`search_query`, not `q`):

```bash
curl -sG "$SERPAPI_BASE_URL/search.json" \
  --data-urlencode "engine=youtube" \
  --data-urlencode "search_query=rust async tutorial" \
  --data-urlencode "api_key=$SERPAPI_API_KEY" | jq
```

Extract organic results, answer box, and related questions:

```bash
curl -sG "$SERPAPI_BASE_URL/search.json" \
  --data-urlencode "engine=google" \
  --data-urlencode "q=what is chezmoi" \
  --data-urlencode "api_key=$SERPAPI_API_KEY" \
  | jq '{organic: [.organic_results[] | {title, link, snippet}], answer_box, related_questions: [.related_questions[]? | .question]}'
```