# Incremental digest

## Objective

Periodically summarize only what is new or changed since the previous run, never the entire source.

## Method

1. **Previous state**: read `## Checkpoint` when present. On the first run, use a reasonable default window such as 24 to 48 hours and disclose it.
2. **Delta**: return only items after the checkpoint, such as new messages, status changes, or documents. Filter minor updates and already reported duplicates.
3. **Report**: produce a short prioritized digest, not an exhaustive raw list.
4. **Memory**: before finishing, use the agent's current durable-memory capability to save the date or source reference. The next run must resume from this checkpoint.

## Semantic prerequisite

This method requires durable memory across runs. The agent maps this need to a capability in its
current contract. Without it, produce a one-time digest and explicitly state that the next run cannot
calculate a reliable delta.

## Rules

- Never report an item already covered by a previous digest.
- When nothing is new, say so briefly rather than forcing content.
- Keep the digest readable in under a minute by prioritizing instead of listing everything.

## Robust checkpoint

Store a source cursor when available, otherwise store a UTC timestamp plus identifiers already seen
at the boundary. Reread a small overlap around the cursor to catch late arrivals, then deduplicate by
stable identifier. A timestamp alone is insufficient when events can share an instant.

Advance the checkpoint only after successful digest production. An interrupted run retains the old
state so undelivered items return in the next run.

## Prioritization and output

Order the delta by impact and required action: blocker, decision, important change, information. Group
notifications describing the same event and limit detail for informational items.

```json
{
  "window": { "from": "previous cursor", "to": "observed cursor" },
  "highlights": [{ "kind": "decision", "summary": "...", "source_id": "..." }],
  "counts": { "new": 0, "changed": 0, "ignored_duplicates": 0 },
  "next_checkpoint": { "cursor": "...", "boundary_ids": [] }
}
```

The method is complete when every event in the window is retained or filtered, no retained identifier
was previously delivered, and the new checkpoint can resume without gaps.
