# Sourced knowledge-base answers

## Objective

Answer a question exclusively from available documents and sources, with citations and no fabrication.

## Method

1. **Search**: query connected sources through available semantic or keyword search. Try several formulations when the first returns nothing relevant.
2. **Read**: retain only material that answers the question and discard noise.
3. **Answer**: write only from retrieved excerpts and cite the document title and link when available for every claim.
4. **No evidence**: explicitly state when nothing relevant was found instead of answering from general knowledge. Suggest another place to search when useful.

## Rules

- When a knowledge base is available, prefer a partial sourced answer to a complete unverifiable one.
- Do not mix general knowledge with sourced content without clearly labeling it.
- Make citations precise enough to recover the passage, including document and section when possible.

## Search and evidence threshold

Transform the question into two to four formulations covering useful synonyms, entities, and dates.
Read neighboring passages so a sentence is not separated from its condition or exception. Deduplicate
excerpts from the same document.

A claim is supported when the cited passage states it directly or permits a simple, explicitly
labeled inference. Shared keywords are insufficient. For a procedure, also find prerequisites,
exceptions, and document version.

## Output contract

```text
Answer
Paragraph with citation [S1].

Sources
[S1] Title, section or page, URI or link

Limitations
Requested information not covered, disagreement, or possibly outdated document.
```

Each citation supports the sentence immediately before it. When sources conflict, present both
positions with dates and scope. The method is complete when every factual claim has recoverable
evidence and uncovered parts are clearly separated.
