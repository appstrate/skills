# Community Skills

A curated list of Agent Skills that work well alongside [Appstrate](https://appstrate.dev). Maintained via PRs — see [CONTRIBUTING.md](./CONTRIBUTING.md#1-link-your-skill-in-communitymd).

## Appstrate-specific

Skills that interact directly with Appstrate (call the REST API, author AFPS packages, drive the CLI).

_Be the first. [Add yours.](./CONTRIBUTING.md#1-link-your-skill-in-communitymd)_

## Complementary

General-purpose skills that pair well when you ship Appstrate agents — commit writing, testing patterns, provider-specific helpers, etc.

_Add one you use every day._

## Recommended skill collections

We vetted the broader ecosystem. The repos below consistently publish high-quality skills and are worth installing alongside Appstrate.

### Official vendor collections

- [**anthropics/skills**](https://github.com/anthropics/skills) — 17 first-party skills from Anthropic. Coverage: PDF/DOCX/PPTX/XLSX, canvas-design, frontend-design, algorithmic-art, brand-guidelines, claude-api, mcp-builder, skill-creator, web-artifacts-builder, webapp-testing, internal-comms, doc-coauthoring, slack-gif-creator, theme-factory. ~73k stars. Apache 2.0.
- [**microsoft/skills**](https://github.com/microsoft/skills) — 132 skills for Azure SDKs and Microsoft AI Foundry. Custom agents, AGENTS.md templates, MCP configurations.

### Major cross-tool curation

- [**VoltAgent/awesome-agent-skills**](https://github.com/VoltAgent/awesome-agent-skills) — 1000+ skills from official dev teams (Anthropic, Google Labs, Vercel, Stripe, Cloudflare, Netlify, Trail of Bits, Sentry, Expo, Hugging Face, Figma) and the community. Compatible with Claude Code, Codex, Gemini CLI, Cursor.
- [**karanb192/awesome-claude-skills**](https://github.com/karanb192/awesome-claude-skills) — 50+ verified skills for Claude Code, Claude.ai, Claude API. TDD, debugging, git workflows, document processing. Community-driven, actively maintained.
- [**sickn33/antigravity-awesome-skills**](https://github.com/sickn33/antigravity-awesome-skills) — 1400+ installable skills for Claude Code, Cursor, Codex CLI, Gemini CLI, Antigravity. 34k+ stars. Ships an installer CLI and skill bundles.

### Specialized domains

- [**K-Dense-AI/scientific-agent-skills**](https://github.com/K-Dense-AI/scientific-agent-skills) — 133 skills for research, science, engineering, finance, and writing. Comprehensive docs + code examples for scientific libraries, databases, and tools.
- [**addyosmani/agent-skills**](https://github.com/addyosmani/agent-skills) — Production-grade engineering skills curated by Addy Osmani.

## Tooling

- [**numman-ali/openskills**](https://github.com/numman-ali/openskills) — Universal skills loader. Brings Anthropic's skills system to every AI coding agent (Claude Code, Cursor, Windsurf, Aider, Codex). Defines the `.agent/skills/` cross-tool convention that Appstrate's `--universal` installer targets.

## Not listed here?

Open a PR editing this file. Keep the description factual, link to a maintained repo, and place it in the section that matches best. We don't rank or approve — we just curate for quality.
