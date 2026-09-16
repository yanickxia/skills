# You.com API — Full Endpoint Reference

Source: You.com API docs (`https://you.com/platform/api-keys`, API reference under `/docs`). Every endpoint is `POST` with a JSON body and the same headers:

```bash
-H "Authorization: Bearer $YDC_API_KEY"
-H "Content-Type: application/json"
```

Base URL: `https://api.you.com` (override with `YOU_API_BASE_URL`).

---

## `POST /api/search`

Search the web and return ranked, cited results.

**Request body**:
| Field | Required | Notes |
|-------|----------|-------|
| `query` | ✓ | Search query string |
| `count` | | Number of results, `1`–`20` (values outside the range are clamped) |
| `freshness` | | Recency filter: `day` / `week` / `month` / `year` |

**Example**:

```bash
curl -s -X POST "$YOU_API_BASE_URL/api/search" \
  -H "Authorization: Bearer $YDC_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query":"you.com search api","count":10,"freshness":"week"}' | jq
```

**Response**: a `results` array of web hits. Each hit carries a title, URL, snippet, and citation metadata suitable for sourcing an answer. Field names can vary by API version — inspect with `.results[] | keys` when unsure.

---

## `POST /api/contents`

Extract the readable text of specific URLs. This is the page-scraping endpoint.

**Request body**:
| Field | Required | Notes |
|-------|----------|-------|
| `urls` | ✓ | Array of URLs to extract, **at most 10 per call** |

**Example**:

```bash
curl -s -X POST "$YOU_API_BASE_URL/api/contents" \
  -H "Authorization: Bearer $YDC_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"urls":["https://example.com/a","https://example.com/b"]}' | jq
```

**Response**: a `results` array with one entry per requested URL. Each entry contains the URL plus the extracted page text (article body, cleaned of boilerplate). Confirm the exact text field name with:

```bash
... | jq '.results[] | keys'
```

To handle more than 10 URLs, split the list into batches of ≤10 and combine the responses.

---

## `POST /api/research`

Run a multi-source research pass and return a synthesized report.

**Request body**:
| Field | Required | Notes |
|-------|----------|-------|
| `query` | ✓ | Research question |

**Example**:

```bash
curl -s -X POST "$YOU_API_BASE_URL/api/research" \
  -H "Authorization: Bearer $YDC_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query":"state of WebGPU support in 2025"}' | jq
```

**Response**: a synthesized, typically citation-backed report. This is a heavier, slower call than `/api/search` — prefer `search` + `contents` when you want control over the sources.

---

## MCP Tool Equivalents

The You.com MCP tools are thin wrappers over the three REST endpoints:

| MCP tool | REST endpoint |
|----------|---------------|
| `you-search` | `POST /api/search` |
| `you-contents` | `POST /api/contents` |
| `you-research` | `POST /api/research` |

Parameters map one-to-one: `you-search` takes `query`, `count`, `freshness`; `you-contents` takes `urls`; `you-research` takes `query`. When a caller cannot reach the network directly, an MCP server or the gateway in [SKILL.md](SKILL.md#custom-gateway-base-url-override) can proxy these same calls.

## Errors

| Code | Meaning |
|------|---------|
| 401 | Missing or invalid API key |
| 402 | Payment required / out of quota |
| 429 | Rate limited |

Error bodies are JSON; dump them with `jq` to see the upstream message.