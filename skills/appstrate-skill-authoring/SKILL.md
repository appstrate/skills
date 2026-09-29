---
name: appstrate-skill-authoring
description: Find, adapt, create, or improve an organization-owned Appstrate method skill. Load this guide when an Appstrate method is missing, triggers incorrectly, guides execution poorly, or must be simplified, including when appstrate-agent-authoring delegates this branch. It searches organizational and external skills before authoring a new method.
---

# Create or improve an Appstrate method skill

Use this guide after confirming that the need belongs to a reusable method. If the request concerns
agent assembly, integrations, its prompt, or its trigger, return that branch to `appstrate-agent-authoring`.

The expected result is a method that several organizational agents can share. Reuse a suitable
existing skill before adapting one, and adapt a credible external skill before creating a competing
method from scratch.

## Source of truth and interface

The target Appstrate instance owns current operations, parameters, and schemas. Prefer the Appstrate
MCP when it is connected to the correct organization. Otherwise, use an explicit CLI profile and its
authenticated API access. Discover and describe the appropriate operation before each read or
mutation. Do not reproduce field names, request-body shapes, version selectors, or error codes here.

This skill owns the writing and evaluation method: the two audiences for descriptions, `SKILL.md`
structure, trigger criteria, and controlled comparison before publication.

When this guide calls `appstrate-agent-authoring`, resolve the accessible skill by its unscoped name. In
Appstrate, retain its canonical `@scope/name` identifier. In a coding agent, use the local catalog. If
it is missing, report the dependency instead of assuming a scope.

## Reference method library

Use this library only after organizational and external discovery found no reusable package. Choose
the branch that matches the need and read only the linked file. First discover and describe the current
operation for reading a package file, then request the exact path in the link. Do not load the full
file index or the entire library. If no branch matches, derive the method from the observed need.

- Review a diff or pull request: [code review](references/code-review.md)
- Write publishable content or a marketing message: [content writing](references/content-writing.md)
- Enrich a lead or maintain a pipeline: [CRM update](references/crm-update.md)
- Qualify an account or prepare a prospect view: [customer research](references/customer-research.md)
- Interpret a table or numeric export: [data analysis](references/data-analysis.md)
- Extract fields from a document: [document extraction](references/doc-extraction.md)
- Triage emails and prepare responses: [email reply](references/email-reply.md)
- Summarize only changes since the previous run: [incremental digest](references/incremental-digest.md)
- Prepare a meeting from several sources: [meeting preparation](references/meeting-prep.md)
- Turn a meeting into decisions and actions: [minutes and actions](references/minutes-actions.md)
- Answer from a document base with citations: [sourced answer](references/sourced-rag.md)
- Research the web with verifiable sources: [sourced web research](references/sourced-research.md)
- Produce progress status from tickets and changes: [sprint report](references/sprint-report.md)
- Classify incoming requests and decide escalation: [triage and sentiment](references/triage-sentiment.md)

A reference is authoring material, not an attachable skill. Adapt it to the organization's context,
remove unsupported assumptions, add the trigger checks required below, and materialize a skill under
the organization's scope. The reference never becomes an agent dependency.

## Process

### 1. Reuse, adapt, or create

Look for an organizational skill that already owns the same conceptual need. Read ambiguous
candidates before deciding.

- Improve the existing skill when its intent and boundary match.
- Keep the name stable during an improvement. A defect does not justify a suffix or duplicate.
- When no organizational skill fits, read [external skill discovery](references/external-skill-discovery.md)
  and search for a credible reusable candidate before authoring a new method.
- Reuse an external skill when its method, runtime assumptions, and license fit the organization.
- Adapt it when the method fits but its interface or context does not. Record required attribution,
  license text, and change notices in the repository or distribution notices that cover the resulting
  package.
- Create a new skill only when no organizational, external, or reference method fits.

If no existing package fits, consult one relevant branch of the reference library above. A reference
accelerates creation, but the actual objective, available access, and observed cases remain the source
of truth.

Before modifying a skill, discover current operations for reading its draft, published versions, and
package files. Read all relevant files, not only the main content. Identify the published baseline,
changes already present in the draft, and the concurrency mechanism required by the update operation.

This step is complete when you can name the selected source, explain why stronger candidates were
rejected, and identify the affected consumers. Do not import, install, publish, or execute an external
package until the user approves the reviewed candidate.

### 2. Keep only the method

Write criteria, heuristics, tradeoffs, business steps, edge cases, and output forms that several agents
could reuse.

Exclude connectors, channels, identifiers, cadence, volume limits, and field mappings specific to one
instance. `appstrate-agent-authoring` owns those decisions.

When the method assumes a runtime capability, express the semantic need and fallback behavior, such as
preserving durable state between runs or publishing a document. The agent maps that need to
capabilities exposed by its current schema.

**Decide where the method runs before writing it.** Publishing a skill distributes it; it does not
force it to run in the cloud. A method runs in an Appstrate agent's sandbox, on a workstation through
a coding agent (Claude Code, Codex) with the tools and tokens of that machine, or in both: the agent
on schedule, the workstation for a backlog or a large volume. State the venues in the agent-facing
description.

A method that runs in both venues keeps one logic and swaps only its transport:

- **A rule that names a command is written wrong.** Rules are stated as operations of the service's
  API (list the messages, move the file), never as the commands of one tool. Command names live only
  in a table of the venues and in each venue's step list.
- Put deterministic logic in a script that knows only the service's API and files, and switch its
  transport with an option: on a workstation it performs the calls itself with a local token; in an
  agent it writes the calls it needs, the agent performs them with its integrations, and the script
  resumes. Responses travel through files, never through the model.
- Both venues read and write the same state in the same place, so either can resume the other's work.
- What the rules cannot settle is judged by the agent's model in the agent venue. On a workstation
  it defaults to a sub-agent of the coding session, which costs no metered run and keeps the data on
  the machine; launch an Appstrate run instead when the task needs what only the agent has, such as
  its integrations or a trace in its run history.
- Flag, where it matters, anything that works in one venue only.

[Two-venue skill template](references/two-venue-skill.md) shows the resulting structure. Read it
before writing a method that runs in both venues.

### 3. Write for both readers

A skill created in the organization has two descriptions that drive two different decisions:

- `manifest.description` is read by the chat when choosing an agent dependency. Describe the covered
  need, its boundary with neighboring methods, and the expected selection action.
- the `SKILL.md` frontmatter `description` is read by the runtime agent. Describe the situations in
  which the agent should open this method to perform its task.

Write them separately. The body cannot repair a description that triggers the wrong action.

Frontmatter includes at least the skill's unscoped name and its agent-facing description. The name
must match the last segment of the package materialized by the runtime.

### 4. Write an executable method

Organize the body in execution order:

1. concrete objective;
2. steps with an observable completion condition;
3. semantic prerequisites the agent must satisfy;
4. rules and edge cases at the point where they become useful;
5. an example or schema only when it changes behavior.

Keep material required on every run in the main file. Put a large reference or rare variant in a
separate file only when it belongs to the package and the body says exactly when to read it.

State target behavior positively. When a safeguard is necessary, include the authorized fallback in
the same rule. Require verifiable and exhaustive criteria instead of adverbs such as "carefully" or
"correctly."

Remove advice the model already follows, obsolete branches, and repeated versions of one rule. During
an improvement, change the smallest surface that explains the observed failure and preserve the rest.

When the method processes items in batches, or can run long enough for the agent's working context
to be summarized mid-run, progress must live outside the conversation. Add a `Progress state` section
that defines, in business terms, what identifies a processed item (stable identifier, cursor, or
path), which results are already delivered and must never be produced again, and the next action.
Tell the agent to record this state with its available state-preservation capabilities after each
completed batch, not only at the end, and to reread it first whenever it resumes or its context was
summarized. Do not name a tool. When no durable capability exists, the fallback is a progress file in
the working directory, updated after each batch. The recorded state wins over recollection: an item
is done only when the record says so.

### 5. Publish the package

**From a workstation with the Appstrate CLI**, author in a local working folder: `appstrate
packages pull` brings the draft into it, `status` shows what the folder would change, `push` writes
it to the draft with its companion files, binaries included, under the lock the folder last saw, and
`publish` cuts the version. A new package is created by `push --create --space <space>`, and the
space is its home: choose it before, since a package cannot later move into a personal space.

**Workstations receive what is published.** `appstrate code sync`, run each session by the Appstrate
plugin for Claude Code, writes the published version of every skill active in the spaces the profile
belongs to into the coding agents' skill directories. Those are generated copies: never edit them,
the next sync overwrites them. `appstrate code sync --source draft --target <agent>` writes the drafts
instead, which is how a draft is tried on a workstation before anyone else receives it.

**Through the API or the MCP**, the skill-creation operation and the draft-update operation accept
file operations alongside the manifest: `references/` and `scripts/` travel with them. Discover the
current contract of each before building the request.

Creating a package publishes its first version at once. Pass the triggering check of step 6 before
creating it, from the working folder placed in a coding agent's skill directory.

Declare in the manifest's skill dependencies every other skill this package relies on: one its
method tells the agent to load, and one whose files its scripts read or import. The declaration is
what makes a dependent visible to anyone about to remove or break that skill, and a script that
reaches a sibling skill's folder without it works on one machine and fails wherever the sibling
was never installed. Pin a range the package was tested against, and when a script finds a sibling
by its folder name, say so in the code: that name is the package's unscoped name.

When neither path is available, import the package as an archive. Pack with `scripts/afps-pack.sh
SOURCE_DIR OUTPUT.afps`. It requires `manifest.json` at the root of
the source directory and stores every file flat at the archive root, preserving subdirectories. **A
wrapping directory inside the archive makes the import fail**, which is the failure this script
exists to prevent.

Verify the packed archive before importing it, then reread the stored package and confirm its files
match what was packed.

**Do not reuse a package id you have just deleted.** Deleting a package cleans its stored files a
little later, at paths that depend only on the id and the version; a package recreated under the
same id in between loses its companion files and its published archive becomes unreadable
(appstrate/appstrate#1612). Prefer a new id; otherwise wait several minutes, then reread both the
draft's files and the published archive.

### 6. Verify triggering

Write two realistic requests that should select the skill and one near-miss that shares its vocabulary
without requesting the same method. Keep all three in a `Triggering` section of the `SKILL.md` so they
remain versioned with the artifact.

In fresh conversations, verify that positive cases load the skill and the near-miss does not. Before
the package exists, test from the working folder placed in a coding agent's skill directory; once it
exists, test the draft synced to the workstation (step 5). If
selection is wrong, correct the descriptions. If selection is right but execution fails, correct the
body.

A check in which the method or expected result was already present in context does not prove
triggering.

## Triggering

- Positive: "Find an existing skill for preparing customer meetings before we create one."
- Positive: "Our invoice extraction skill misses tax fields. Improve the shared method."
- Near-miss: "Connect our Gmail account to the support agent." This belongs to access configuration,
  not method authoring.

## Improvement loop

Apply this loop before proposing publication of a change:

1. **Reproduce.** Choose cases that expose the defect and define the expected signal before changing
   the draft.
2. **Modify.** Update the complete draft with the concurrency mechanism described by the current
   operation. If the draft changed, reread and reapply the change instead of overwriting concurrent
   work.
3. **Compare.** Run two adjacent tests with the same test agent, prompt, input, and configuration. Only
   this dependency's selection changes: published version in the first run, draft in the second. Use
   the run-specific selection mechanism described by the MCP tool during the test.
4. **Observe.** Read both run resources and logs. Confirm in their resolved dependency snapshots that
   each loaded the stated variant. Then compare output, errors, retries, cost, and every criterion
   defined before modification.
5. **Decide.** Keep the draft only if it improves positive cases without triggering the near-miss or
   degrading an existing constraint.

For a method that runs on a workstation, compare the same task in two fresh coding-agent sessions,
one with the published version and one with the draft synced locally, or use the coding agent's
skill-evaluation tooling when it has some.

When no published version exists, compare a run without the new skill to the same run with the draft.
A requested selection absent from the resolved snapshot is not proof.

Present run IDs, observed differences, and uncertainties. A successful run never publishes the
method automatically. Publication remains a separate human decision.

## Final check

Consider the draft ready to propose only when:

- organizational and external candidates were checked before creating a new skill;
- no suitable skill already owns the need, or the existing one was reused, adapted, or improved;
- all relevant files and the published baseline were read;
- every instruction belongs to the method, not an agent instance;
- both descriptions drive the correct action for their reader;
- every step has an observable completion condition;
- prerequisites are semantic needs with a fallback;
- a batched or long-running method keeps its progress state outside the conversation;
- companion files, when present, are in the stored draft and in the published archive;
- the venues are decided, and a method that runs in both keeps command names out of its rules;
- every other skill the method loads or its scripts read is declared as a skill dependency;
- two positive cases and one near-miss were tested in fresh contexts;
- the draft was tried in every venue the method runs in;
- for an improvement, the comparison changes only one dependency and resolved snapshots prove its
  selection;
- every remaining line changes an agent decision or action.

If any proof is missing, keep the draft unpublished and name the remaining verification.
