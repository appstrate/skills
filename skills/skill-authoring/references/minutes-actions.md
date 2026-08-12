# Meeting summary, decisions, and actions

## Objective

Turn a transcript or meeting notes into a useful short summary, confirmed decisions, and follow-up
actions with owners and due dates when named.

## Method

1. **Context**: when `## Checkpoint` is injected, use its summary of the previous related meeting and open actions without asking again.
2. **Analyze**: separate confirmed decisions, actions, and attention points such as disagreements, open questions, and postponed topics. Include an owner or deadline only when explicitly named.
3. **Report**: follow the agent's declared schema, then produce readable minutes with summary, decisions, an action table, and attention points.
4. **Memory**: when durable memory exists, save a dated recap of topics and open actions. When archival capability also exists, preserve structural decisions such as firm commitments, budgets, or contractual dates.

## Semantic prerequisites

Cross-meeting follow-up requires durable memory, and archiving requires long-term retention. The agent
maps these needs to its current contract. Without them, produce today's summary and claim no ongoing
tracking.

## Rules

- Never invent a missing owner or due date. Leave the field null.
- Write each action as an action verb plus a clear deliverable.
- For an empty or unintelligible transcript, report the problem instead of filling gaps.

## Classification tests

A **decision** contains a final agreement or choice, not a discussed option. An **action** describes a
verifiable future change. An **open question** remains open even when one option received more
attention.

Keep short evidence with a timestamp or speaker when available. A collective owner such as "the team"
remains collective. Normalize a relative deadline from the meeting date only when that date is known.

## Output contract

```json
{
  "summary": "summary in a few sentences",
  "decisions": [{ "decision": "...", "evidence": "..." }],
  "actions": [
    { "action": "verb and deliverable", "owner": null, "due_date": null, "evidence": "..." }
  ],
  "open_questions": [{ "question": "...", "next_step": null }]
}
```

Deduplicate restatements of the same decision or action. Minutes are complete when every structured
item traces to the transcript, absent fields remain null, and disagreements are not turned into
decisions.
