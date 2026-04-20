# Appstrate Skills

Agent Skills for working with [Appstrate](https://appstrate.dev), the open-source agent runtime platform. Install one into your coding agent (Claude Code, Cursor, Google Antigravity, Windsurf, …) and it becomes an Appstrate expert.

**License:** Apache 2.0 (first-party skills). Community links on this page point to their own licenses.

## Quick install

Universal one-liner (auto-detects your coding agent and drops the skill in the right place):

```bash
curl -fsSL https://skills.appstrate.dev | bash -s appstrate
```

Or pick your target explicitly:

```bash
curl -fsSL https://skills.appstrate.dev | bash -s appstrate --claude
curl -fsSL https://skills.appstrate.dev | bash -s appstrate --cursor
curl -fsSL https://skills.appstrate.dev | bash -s appstrate --antigravity
curl -fsSL https://skills.appstrate.dev | bash -s appstrate --universal
```

Prefer `git clone` directly? Skills are plain folders — see each skill's README below for the target path per agent.

### Updating

Skills evolve. Pull the latest version by re-running the installer with `--update`:

```bash
curl -fsSL https://skills.appstrate.dev | bash -s appstrate --update
```

The flag is an alias for `APPSTRATE_SKILLS_FORCE=1` — it overwrites the existing install instead of failing. Without `--update`, a fresh install into an existing directory errors out as a safety net.

## First-party skills

| Skill | What it does |
|---|---|
| [`appstrate`](./skills/appstrate) | Install Appstrate, sign in, call the REST API, author AFPS packages, manage profiles across cloud + self-hosted + dev instances |

More first-party skills ship as we write them. Planned: `afps-authoring`, `agent-writing`, `multi-tenancy`, `self-hosting-troubleshooter`.

## Community skills

A curated awesome-list of skills that work well alongside Appstrate, maintained by the community: **[COMMUNITY.md](./COMMUNITY.md)**.

Open a PR editing that file to add yours — no gate-keeping, just keep it related and linkable.

## Supported coding agents

| Agent | Install path (per-user) | Install path (per-project) |
|---|---|---|
| [Claude Code](https://docs.claude.com/en/docs/claude-code) | `~/.claude/skills/<name>/` | `.claude/skills/<name>/` |
| [Cursor](https://cursor.com/docs/skills) | — | `.cursor/skills/<name>/` |
| [Google Antigravity](https://antigravity.google/docs/skills) | `~/.gemini/antigravity/skills/<name>/` | `.agent/skills/<name>/` |
| Windsurf, Aider, any AGENTS.md-aware agent | — | `.agent/skills/<name>/` (via [OpenSkills](https://github.com/numman-ali/openskills)) |

## What is an Agent Skill?

A directory with a `SKILL.md` file. The markdown has YAML frontmatter (`name`, `description`) that tells your agent when to use it, followed by instructions, references, and scripts the agent can load on demand. Standard introduced by [Anthropic](https://github.com/anthropics/skills); now supported (with minor path variations) by every major coding agent.

The `description` field matters: that's what your agent reads to decide whether to load the skill for a given request. Keep it rich, keyword-dense, and specific to triggers.

## Contributing

See **[CONTRIBUTING.md](./CONTRIBUTING.md)** — two paths: add a first-party skill (PR a folder under `skills/`) or link your own repo (PR a line in `COMMUNITY.md`).
