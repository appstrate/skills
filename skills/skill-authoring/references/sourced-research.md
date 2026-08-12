# Sourced web research

## Objective

Research current information about a topic, competitor, or market and produce a structured, sourced
synthesis.

## Method

1. **Frame**: specify the topic, period, and angle before searching.
2. **Search**: use several complementary queries and prefer primary sources such as official sites, releases, and product documentation over aggregators.
3. **Synthesize**: organize by theme rather than source and cite every claim with source name and link.
4. **Freshness**: report source dates, especially for fast-changing subjects such as pricing, features, and news.

## Rules

- Make no claim without an identifiable source.
- Explicitly report contradictory information instead of choosing arbitrarily.
- When research finds no solid evidence, say so rather than filling gaps with unverified knowledge.

## Research plan

Break the question into claims to verify before searching. For each, identify the authoritative source
and an independent control source when warranted. Stop when each important claim has sufficient
evidence or new queries no longer change the synthesis.

Indicative hierarchy: official document or primary data, subject documentation or statement,
identifiable specialist publication, aggregator. A lower source can guide discovery but should not
replace an easily available primary source.

## Evidence matrix

```json
{
  "claim": "precise claim",
  "status": "confirmed | disputed | unsupported",
  "sources": [{ "title": "...", "url": "...", "published_at": null }],
  "notes": "scope, method, or contradiction"
}
```

Write the synthesis by theme from this matrix, then provide sources. Include access dates for undated
pages and distinguish publication date from event date.

Research is complete when major claims are confirmed, disputed, or marked unsupported and the reader
can recover each source.
