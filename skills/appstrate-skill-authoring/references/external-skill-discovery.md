# External skill discovery

## Objective

Find a maintained, portable skill that already covers the required method before creating a new one.
Discovery produces a reviewed candidate and a reuse decision. It does not authorize installation or
execution.

## Search order

Load the accessible `appstrate-web-search` skill because public catalogs and repositories change frequently.
Search in this order and stop when an authoritative source provides an exact, reviewable match:

1. the product or service vendor's official skill or plugin repository;
2. official cross-product collections from model and platform vendors;
3. an official marketplace, restricted to first-party entries or an independently verified upstream;
4. the Skills directory at `https://skills.sh/`, using its ownership, provenance, and audit information
   as discovery signals rather than proof of quality;
5. maintained community collections and GitHub repository search.

### Official cross-product sources

- Anthropic skills: `https://github.com/anthropics/skills`
- OpenAI plugins, including skill-only plugins: `https://github.com/openai/plugins`
- Microsoft skills: `https://github.com/microsoft/skills`
- Google skills: `https://github.com/google/skills`

The former OpenAI catalog at `https://github.com/openai/skills` is deprecated. Do not use it as the
current source when a maintained equivalent exists in OpenAI Plugins.

### Official product and platform sources

Use the source that owns the product involved in the request:

- AWS: `https://github.com/aws/agent-toolkit-for-aws`
- NVIDIA: `https://github.com/NVIDIA/skills`
- AMD: `https://github.com/amd/skills`
- Hugging Face: `https://github.com/huggingface/skills`
- Vercel: `https://github.com/vercel-labs/agent-skills`
- Cloudflare: `https://github.com/cloudflare/skills`
- Firebase: `https://github.com/firebase/skills`
- Stripe: `https://github.com/stripe/ai`
- Supabase: `https://github.com/supabase/agent-skills`
- Sentry: `https://github.com/getsentry/sentry-for-ai`
- HashiCorp: `https://github.com/hashicorp/agent-skills`
- Elastic: `https://github.com/elastic/agent-skills`
- Expo: `https://github.com/expo/skills`
- Databricks: `https://github.com/databricks/databricks-agent-skills`
- WordPress: `https://github.com/WordPress/agent-skills`
- Apify: `https://github.com/apify/agent-skills`
- LangChain and LangSmith: `https://github.com/langchain-ai/langchain-plugins`
- Meta Quest and Horizon OS: `https://github.com/meta-quest/agentic-tools`
- Cohere, narrowly for maintaining long-lived vLLM forks: `https://github.com/cohere-ai/vllm-skills`

These are product-specific sources, not general method libraries. Prefer them for current product
usage, configuration, migration, and troubleshooting guidance. Confirm whether the repository itself
is installable or is a source that builds agent-specific distributions, as in Sentry's case.

### Official discovery surfaces with mixed provenance

- GitHub Agent Skills and `gh skill`: `https://docs.github.com/en/copilot/concepts/agents/about-agent-skills`
- xAI plugin marketplace: `https://github.com/xai-org/plugin-marketplace`

An official marketplace is not proof that every entry is first-party. For xAI, distinguish packages
under `plugins/`, which xAI identifies as first-party, from entries under `external_plugins/`. For any
remote package, review the pinned upstream revision and the upstream owner's license and security
posture.

### Compatible runtimes that are not public source catalogs

Mistral Vibe supports the Agent Skills standard and provides built-in skills, but its public
documentation is not a reusable source repository. Grok Build also supports `SKILL.md` packages, while
xAI distributes them through its plugin marketplace. Do not treat runtime support as evidence that a
portable, licensed vendor catalog exists. Cohere's public source is a narrow vLLM maintenance package,
not a general Cohere catalog. Recheck vendor documentation because this status can change.

### General discovery and community sources

- Agent Skills standard: `https://agentskills.io/`
- Skills directory: `https://skills.sh/`
- Community index: `https://github.com/VoltAgent/awesome-agent-skills`

Search by desired outcome, business domain, product name, and the terms `Agent Skill` or `SKILL.md`.
Popularity can suggest candidates but never establishes quality, safety, or suitability.

## Review each candidate

Read the complete candidate package before recommending it, including its instructions, references,
scripts, manifests, license, notices, and recent repository history. Evaluate:

- **Fit**: its objective, trigger boundary, output, and edge cases match the observed need.
- **Portability**: its required tools and runtime capabilities exist in Appstrate or have a clear
  semantic equivalent.
- **Provenance**: the source and maintainer are identifiable, and the reviewed tag or commit can be
  recorded.
- **Publisher class**: the candidate is first-party, officially curated third-party, or community
  maintained. Record the class instead of describing every marketplace entry as official.
- **License**: reuse and modification are permitted, and required attribution can travel with the
  package.
- **Safety**: scripts, hooks, network calls, credential handling, and destructive actions are explicit
  and proportionate.
- **Maintenance**: important dependencies and instructions are current enough for the target runtime.
- **Evidence**: examples or tests demonstrate the claimed behavior without replacing local validation.
- **Integrity**: prefer a pinned revision and verify signatures, checksums, skill cards, or evaluation
  artifacts when the publisher supplies them. Their absence does not prove a package unsafe, but their
  presence strengthens the provenance record.

Treat registry rankings, stars, badges, and automated audits as signals only. Reject a candidate when
its source cannot be established, its license is missing or incompatible, or reviewing its executable
content is not possible.

## Decide

- **Reuse** when the package is trustworthy, portable, licensed appropriately, and already matches the
  method.
- **Adapt** when its method is valuable but organization-specific assumptions or runtime interfaces must
  change. Record the upstream URL and reviewed revision, preserve notices, and identify modified files.
- **Create** when no credible candidate covers the need. Use the relevant internal reference method if
  one exists.

Present the strongest candidates with source, license, fit, important risks, and the recommended
decision. Ask for approval before importing or installing the selected package. After approval, test it
against the same positive cases and near-miss required for an authored skill.

Discovery is complete when an authoritative exact match was reviewed, or the main official sources and
a general directory were searched, every serious candidate has a documented decision, and creation is
justified by the remaining gap.
