---
name: skill-authoring
description: Create or improve an organization-owned method skill. Load this guide when a method is missing, triggers incorrectly, guides execution poorly, or must be simplified, including when agent-authoring delegates this branch. It contains reference methods to read only when they match the need.
---

# Create or improve a method skill

Use this guide after confirming that the need belongs to a reusable method. If the request concerns
agent assembly, integrations, its prompt, or its trigger, return that branch to `agent-authoring`.

The expected result is a method that several organizational agents can share. Preserve a good
existing method instead of creating a competing variant.

## Source of truth and interface

The target Appstrate instance owns current operations, parameters, and schemas. Prefer the Appstrate
MCP when it is connected to the correct organization. Otherwise, use an explicit CLI profile and its
authenticated API access. Discover and describe the appropriate operation before each read or
mutation. Do not reproduce field names, request-body shapes, version selectors, or error codes here.

This skill owns the writing and evaluation method: the two audiences for descriptions, `SKILL.md`
structure, trigger criteria, and controlled comparison before publication.

When this guide calls `agent-authoring`, resolve the accessible skill by its unscoped name. In
Appstrate, retain its canonical `@scope/name` identifier. In a coding agent, use the local catalog. If
it is missing, report the dependency instead of assuming a scope.

## Reference method library

Use this library as a starting point when no organizational skill owns the method yet. After checking
existing skills, choose the branch that matches the need and read only the linked file. First discover
and describe the current operation for reading a package file, then request the exact path in the
link. Do not load the full file index or the entire library. If no branch matches, derive the method
from the observed need.

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

### 1. Choose creation or improvement

Look for an organizational skill that already owns the same conceptual need. Read ambiguous
candidates before deciding.

- Improve the existing skill when its intent and boundary match.
- Create a new skill only when no method has the same conceptual owner.
- Keep the name stable during an improvement. A defect does not justify a suffix or duplicate.

If no existing skill fits, consult one relevant branch of the library above. A reference accelerates
creation, but the actual objective, available access, and observed cases remain the source of truth.

Before modifying a skill, discover current operations for reading its draft, published versions, and
package files. Read all relevant files, not only the main content. Identify the published baseline,
changes already present in the draft, and the concurrency mechanism required by the update operation.

This step is complete when you can name the failing rule, its current source, and affected consumers.

### 2. Keep only the method

Write criteria, heuristics, tradeoffs, business steps, edge cases, and output forms that several agents
could reuse.

Exclude connectors, channels, identifiers, cadence, volume limits, and field mappings specific to one
instance. `agent-authoring` owns those decisions.

When the method assumes a runtime capability, express the semantic need and fallback behavior, such as
preserving durable state between runs or publishing a document. The agent maps that need to
capabilities exposed by its current schema.

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

### 5. Verify triggering

Write two realistic requests that should select the skill and one near-miss that shares its vocabulary
without requesting the same method. Keep all three in a `Triggering` section of the `SKILL.md` so they
remain versioned with the artifact.

In fresh conversations, verify that positive cases load the skill and the near-miss does not. If
selection is wrong, correct the descriptions. If selection is right but execution fails, correct the
body.

A check in which the method or expected result was already present in context does not prove
triggering.

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

When no published version exists, compare a run without the new skill to the same run with the draft.
A requested selection absent from the resolved snapshot is not proof.

Present run IDs, observed differences, and uncertainties. A successful run never publishes the
method automatically. Publication remains a separate human decision.

## Final check

Consider the draft ready to propose only when:

- no existing skill already owns the need, or the existing one was improved;
- all relevant files and the published baseline were read;
- every instruction belongs to the method, not an agent instance;
- both descriptions drive the correct action for their reader;
- every step has an observable completion condition;
- prerequisites are semantic needs with a fallback;
- two positive cases and one near-miss were tested in fresh contexts;
- for an improvement, the comparison changes only one dependency and resolved snapshots prove its
  selection;
- every remaining line changes an agent decision or action.

If any proof is missing, keep the draft unpublished and name the remaining verification.
