# Brave Search — Full Endpoint Reference

Source: Brave Search API public documentation. All paths below are relative to the base URL (`https://api.search.brave.com` by default, or `$BRAVE_SEARCH_BASE_URL`).

Every endpoint requires:

```
Accept: application/json
X-Subscription-Token: <your key>
```

Auth is the `X-Subscription-Token` header, **not** `Authorization: Bearer`.

## Servers

```
https://api.search.brave.com                   # official direct connection
${BRAVE_SEARCH_BASE_URL}                        # self-hosted gateway override
```

---

## Shared Query Parameters

These apply to most search endpoints.

| Param | Type | Notes |
|-------|------|-------|
| `q` | string | Required query (web/news/images/videos). Sent as the `query` field when using `POST`. |
| `count` | int | Results per page, `1`–`20`. Default `20`. |
| `offset` | int | Page offset, `0`–`9`. Default `0`. |
| `country` | string | 2-letter country code, e.g. `US`, `GB`, `CN`. |
| `search_lang` | string | Result language tag, e.g. `en`, `zh-hans`. |
| `ui_lang` | string | UI/response-formatting language tag. |
| `safesearch` | enum | `off` / `moderate` / `strict`. Default `moderate`. |
| `freshness` | enum / range | `pd` (24h) / `pw` (7d) / `pm` (31d) / `py` (365d) / `YYYY-MM-DDtoYYYY-MM-DD`. |
| `spellcheck` | bool | Enable/disable query spellcheck. |
| `extra_snippets` | bool | Include additional excerpts per web result (plan-dependent). |

Complex queries can be sent as a `POST` with body `{"query": "..."}` instead of a `q` query parameter.

---

## Web Search

### `GET /res/v1/web/search`

Ranked web page results.

**Query params**: shared params above, plus:

| Param | Notes |
|-------|-------|
| `goggles` | Custom ranking / re-ranking definition. |
| `result_filter` | Comma-separated subset of result types to include (`web,news,images,videos,...`). |
| `text_decorations` | Highlight query terms in snippets. |
| `operators` | Include query operators in the response metadata. |

**Response 200** (`web` key):
```json
{
  "web": {
    "type": "search",
    "results": [
      {
        "title": "Example page",
        "url": "https://example.com/article",
        "description": "Snippet text with <strong>highlighted</strong> terms.",
        "age": "2 days ago",
        "profile": {"name": "Example", "long_name": "example.com"},
        "language": "en",
        "meta_url": {"hostname": "example.com", "scheme": "https"}
      }
    ]
  }
}
```

Key `web.results[]` fields:
| Field | Notes |
|-------|-------|
| `title` | Result title |
| `url` | Canonical result URL |
| `description` | Snippet / excerpt |
| `age` | Human-readable freshness, e.g. `3 days ago` |
| `language` | Detected result language |
| `profile` | Source profile (`name`, `long_name`) |
| `meta_url` | Parsed URL parts (`scheme`, `hostname`, `path`, ...) |

Response may also include `query` metadata and `mixed` ranking info. Field availability varies by plan — **verify against live response**.

---

## News Search

### `GET /res/v1/news/search`

Fresh, news-oriented results. Prioritizes recency over the general web index.

**Query params**: shared params above.

**Response 200** (`news` key):
```json
{
  "news": {
    "type": "news",
    "results": [
      {
        "title": "Headline",
        "url": "https://news.example.com/story",
        "description": "Summary of the story.",
        "age": "5 hours ago",
        "page_age": "2026-09-16T08:00:00",
        "meta_url": {"hostname": "news.example.com"}
      }
    ]
  }
}
```

Key `news.results[]` fields:
| Field | Notes |
|-------|-------|
| `title` | Headline |
| `url` | Article URL |
| `description` | Summary |
| `age` | Relative age, e.g. `5 hours ago` |
| `page_age` | Absolute publish timestamp (ISO 8601) — **verify against live response** |
| `meta_url` | Parsed URL parts |
| `thumbnail` | Preview image, when present |

---

## Image Search

### `GET /res/v1/images/search`

**Query params**: shared params above.

**Response 200** (`images` key):
```json
{
  "images": {
    "type": "images",
    "results": [
      {
        "title": "Image title",
        "url": "https://example.com/page-with-image",
        "source_url": "https://images.example.com/photo.jpg",
        "thumbnail": {"src": "https://imgs.search.brave.com/..."},
        "properties": {"width": 1200, "height": 800}
      }
    ]
  }
}
```

Key `images.results[]` fields:
| Field | Notes |
|-------|-------|
| `title` | Image title |
| `url` | Page hosting the image |
| `source_url` | Direct image URL |
| `thumbnail.src` | Thumbnail URL |
| `properties` | `width` / `height` when reported — **verify against live response** |

---

## Video Search

### `GET /res/v1/videos/search`

**Query params**: shared params above.

**Response 200** (`videos` key):
```json
{
  "videos": {
    "type": "videos",
    "results": [
      {
        "title": "Video title",
        "url": "https://video.example.com/watch",
        "description": "Video description.",
        "age": "1 week ago",
        "thumbnail": {"src": "https://imgs.search.brave.com/..."},
        "meta_url": {"hostname": "video.example.com"}
      }
    ]
  }
}
```

Key `videos.results[]` fields:
| Field | Notes |
|-------|-------|
| `title` | Video title |
| `url` | Watch page URL |
| `description` | Description / snippet |
| `age` | Relative age |
| `thumbnail.src` | Preview image |
| `meta_url` | Parsed URL parts |

Video duration/creator fields are not consistently documented — **verify against live response**.

---

## Suggest (Autocomplete)

### `GET /res/v1/suggest/search`

Query autocompletion suggestions.

**Query params**:
| Param | Notes |
|-------|-------|
| `q` | Required prefix to complete |
| `country` | 2-letter country code |
| `search_lang` | Language tag |
| `count` | Max suggestions |
| `rich` | Include enriched suggestion metadata |

**Response 200**:
```json
{
  "results": [
    {"query": "brave search api", "is_entity": false},
    {"query": "brave search api pricing", "is_entity": false}
  ]
}
```

`results[].query` is the suggestion; `is_entity` marks entity-backed suggestions — **verify against live response**.

---

## Spellcheck

### `GET /res/v1/spellcheck/search`

Correct a possibly misspelled query.

**Query params**:
| Param | Notes |
|-------|-------|
| `q` | Required query to check |
| `country` | 2-letter country code |
| `search_lang` | Language tag |

**Response 200**:
```json
{
  "results": [
    {"query": "corrected query"}
  ]
}
```

An empty `results` array means no correction was found — **verify against live response**.

---

## Local / POIs

### `GET /res/v1/local/pois`

Point-of-interest / local business lookup.

**Query params**: shared params above (`q`, `country`, `search_lang`), plus location context when supported.

**Response 200** (`locations` key):
```json
{
  "locations": {
    "results": [
      {
        "id": "loc-1",
        "title": "Place name",
        "description": "Category and address",
        "coordinates": [51.5074, -0.1278]
      }
    ]
  }
}
```

`locations.results[]` fields (`id`, `title`, `description`, `coordinates`) — **verify against live response**.

---

## Summarizer

### `GET /res/v1/summarizer/search`

Generate a summary for a web result. Availability depends on plan.

**Query params**:
| Param | Notes |
|-------|-------|
| `key` | Summarizer key / result reference |
| `entity_info` | Include entity metadata |
| `inline_references` | Embed inline citation references |

**Response 200**:
```json
{
  "summary": [
    {"type": "token", "data": "Summarized text..."}
  ]
}
```

The exact shape (`summary`, `title`, `enum` blocks) varies — **verify against live response**.

---

## Errors

All errors return a JSON body with details under `errors`:

```json
{
  "errors": [
    {"code": "SUBSCRIPTION_TOKEN_INVALID", "detail": "The provided subscription token is invalid."}
  ]
}
```

## HTTP Status Cheatsheet

| Code | Meaning |
|------|---------|
| 200 | OK |
| 401 | Missing / invalid / expired `X-Subscription-Token` |
| 422 | Invalid query parameter (bad enum, out-of-range `count`/`offset`) |
| 429 | Rate limited or quota exceeded — back off exponentially |

## Notes

- Endpoint paths and field names follow the public Brave Search API schema. Fields marked **verify against live response** are plan- or version-dependent and may be absent.
- Response shape is always an object keyed by result type (`web`, `news`, `images`, `videos`, `locations`), never a bare array.
- This API returns titles, URLs, and snippets; it does not return full article bodies.