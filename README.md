# skills

A collection of Claude Code skills.

Each subdirectory is a self-contained skill with its own `SKILL.md` (frontmatter-defined name, description, and trigger hints) plus any supporting reference files.

## Available skills

| Skill | Description |
|-------|-------------|
| [model-onboarding](skills/ai/model-onboarding/) | AI: verify Chat, Messages, and Responses APIs, model metadata, streaming, complete tool-call round trips, and real-client compatibility. |
| [trilium-etapi](trilium-etapi/) | Interact with a Trilium Notes server via the ETAPI REST API — notes, branches, attributes, attachments, day/week/month notes. |
| [brave-search](brave-search/) | Web, news, image, and video search via the Brave Search API — freshness, language, and safe-search filters. |
| [serpapi-search](serpapi-search/) | Structured SERP data from 100+ engines (Google, Bing, Baidu, YouTube, DuckDuckGo) via the SerpApi REST API. |
| [youcom-search](youcom-search/) | Cited web search and batch URL content extraction (up to 10 URLs per call) via the You.com API. |

## Installing with `npx skills`

From this repository root, install the `trilium-etapi` skill for Codex:

```bash
npx skills add . --skill trilium-etapi --agent codex -g -y
```

Install for all supported agents instead:

```bash
npx skills add . --skill trilium-etapi --agent '*' -g -y
```

Use project-level installation by omitting `-g`:

```bash
npx skills add . --skill trilium-etapi --agent codex -y
```

After pushing this repository to GitHub, the same skill can be installed remotely:

```bash
npx skills add yanickxia/skills --skill trilium-etapi --agent codex -g -y
```

Check installation:

```bash
npx skills ls -g --agent codex
```

By default local installs are symlinked into agent directories. Add `--copy` if you want copied files instead.

## Layout

```
<skill-name>/
├── SKILL.md          # entry point (name, description, content)
├── api-reference.md  # optional detailed reference
└── Makefile          # publish helper (clawhub)
```

## Publishing

Each skill's `Makefile` bumps `VERSION` and publishes via `clawhub`:

```bash
cd <skill-name>
make publish                 # uses VERSION from Makefile
make publish VERSION=0.0.2   # override
```
