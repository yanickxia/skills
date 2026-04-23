# skills

A collection of Claude Code skills.

Each subdirectory is a self-contained skill with its own `SKILL.md` (frontmatter-defined name, description, and trigger hints) plus any supporting reference files.

## Available skills

| Skill | Description |
|-------|-------------|
| [trilium-etapi](trilium-etapi/) | Interact with a Trilium Notes server via the ETAPI REST API — notes, branches, attributes, attachments, day/week/month notes. |

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
