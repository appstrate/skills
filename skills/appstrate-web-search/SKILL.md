---
name: appstrate-web-search
description: Search the web or read URLs through Appstrate. Load this Appstrate guide whenever a request requires external web information through an Appstrate connector. It selects a live integration and connection, runs a bounded inline agent, and returns only findings supported by observed sources.
---

# Search the web through an Appstrate inline run

The chat or coding agent orchestrates the task while an Appstrate agent uses the web connector. The
result must be grounded in pages that were actually retrieved, with URLs that support every material
claim.

## 1. Define the required evidence

Choose one branch before searching:

- **search**: discover pages from a question;
- **read**: extract or summarize supplied URLs;
- **search then read**: discover candidates, then read only the most relevant pages.

Set an effort bound and stopping condition in the run prompt. A routine question needs a small set of
independent, directly relevant sources. A sensitive or disputed claim requires a primary source when
one exists.

This step is complete when the run knows which claims to support, how many sources to seek, and when
to stop.

## 2. Select from the live catalog

Discover integrations and connections through the current Appstrate contract. Inspect candidate
details before choosing. Capabilities, tools, allowed destinations, and connection state must come
from the live contract, not a memorized provider list.

Choose the connector that covers the whole branch with the fewest intermediaries. Search capability
does not guarantee full-page retrieval, and URL reading does not guarantee discovery. If no candidate
fits, follow the current connection workflow. If no viable connector exists, state the limitation and
request an accessible URL or the source content.

This step is complete when an available connector covers the required evidence or the catalog proves
that no web path exists.

## 3. Run once

Use the current inline-run and wait operation. With MCP, prefer `run_and_wait` when exposed. With the
CLI, inspect installed help and use the corresponding authenticated API path. Give the run:

- a human-readable title;
- only the connector and tools verified in the previous step;
- the question, optional URLs, effort bound, and stopping condition;
- a useful progress instruction and a final result through the current output mechanism.

Combine search and reading in one run unless a human decision is required between them. Preserve each
finding's URL and, when available, title, author or organization, and publication date. An inaccessible
page is an observed failure, not a source.

This step is complete when the operation returns a terminal result and the used sources are
identifiable in the result or durable output.

## 4. Report

Answer from the observed result. Place citations next to the claims they support and distinguish
established facts, disagreements, and inferences. If the run is empty or weak, change one useful
dimension, such as query, source type, or connector, then make at most one targeted retry.

The research is complete when every important claim has a relevant source or the remaining access
limit is stated precisely.
