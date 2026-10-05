# skills

A collection of agent skills organized by capability.

Each directory under `skills/<category>/` is a self-contained skill with its own `SKILL.md` (frontmatter-defined name, description, and trigger hints) plus any supporting resources.

## Available skills

| Category | Skill | Description |
|----------|-------|-------------|
| AI | [model-onboarding](skills/ai/model-onboarding/) | Onboard models and providers: verify Chat, Messages, and Responses APIs, model metadata, streaming, tool calls, routing, and real-client compatibility. |
| Search | [brave-search](skills/search/brave-search/) | Web, news, image, and video search via the Brave Search API — freshness, language, and safe-search filters. |
| Search | [serpapi-search](skills/search/serpapi-search/) | Structured SERP data from 100+ engines (Google, Bing, Baidu, YouTube, DuckDuckGo) via the SerpApi REST API. |
| Search | [youcom-search](skills/search/youcom-search/) | Cited web search and batch URL content extraction (up to 10 URLs per call) via the You.com API. |
| Knowledge | [trilium-etapi](skills/knowledge/trilium-etapi/) | Interact with a Trilium Notes server via the ETAPI REST API — notes, branches, attributes, attachments, day/week/month notes. |

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
skills/
├── ai/
│   └── model-onboarding/
├── search/
│   ├── brave-search/
│   ├── serpapi-search/
│   └── youcom-search/
└── knowledge/
    └── trilium-etapi/

skills/<category>/<skill-name>/
├── SKILL.md          # entry point (name, description, content)
├── api-reference.md  # optional detailed reference
├── references/       # optional task-specific guidance
├── agents/           # optional agent UI metadata
├── scripts/          # optional executable helpers
├── tests/            # optional validation scripts
└── Makefile          # publish helper (clawhub)
```

## Publishing

Each skill's `Makefile` bumps `VERSION` and publishes via `clawhub`:

```bash
cd skills/<category>/<skill-name>
make publish                 # uses VERSION from Makefile
make publish VERSION=0.0.2   # override
```
