# Email triage and reply drafts

## Objective

Triage an inbox and prepare replies in the user's tone without sending them automatically.

## Method

1. **Triage**: classify each message by urgency and category, such as today, can wait, informational, or probable spam. Identify priority senders when context allows.
2. **Draft**: write a complete reply for messages that need one. Apply an organizational brand-voice method when the agent depends on it.
3. **Report**: list processed messages with categories and provide review-ready drafts.

## Rules

- Never send a message. A draft remains a proposal for user approval.
- Flag ambiguity or missing information instead of inventing an answer.
- Respect the received message's language and appropriate formality.

## Priority heuristic

Prioritize commitments with near deadlines, blocking incidents, requests from priority contacts, and
messages where inaction creates a cost. Urgent tone alone does not make a message urgent. Keep
category, urgency, and sentiment separate so a frustrated but non-urgent message is not over-ranked.

Before drafting, identify the question, available facts, expected decision, and items that need
confirmation. A reply may ask one targeted question instead of filling missing information.

## Output contract

```json
{
  "message_id": "identifier",
  "category": "stable category",
  "priority": "today | soon | informational",
  "reason": "observed signal",
  "draft": { "subject": "subject", "body": "complete reply" },
  "needs_user_input": []
}
```

The draft responds in the thread's language, includes essential details, and remains proportionate to
the request. The method is complete when every in-scope message has a justified classification and
every needed response has either a complete draft or a blocking question.
