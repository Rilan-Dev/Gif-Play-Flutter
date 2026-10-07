# Issues / Risks

## I-001 — Current persistence is not suitable as the sole 500-item media store
Status: OPEN
Impact: performance, data size, queryability.
Plan: introduce a database-backed repository.

## I-002 — Current feed is remote HTML scraping
Status: OPEN
Impact: selectors/source changes can break home/search.
Plan: isolate parser/source adapter and add defensive parsing tests.

## I-003 — MediaItem and GifItem have different identity semantics
Status: OPEN
Impact: duplicate detection, collection membership, cache lookup, restoration.
Plan: establish a stable canonical media identity.

## I-004 — Existing test suite is insufficient
Status: OPEN
Impact: regressions can pass unnoticed.
Plan: add unit/widget/integration coverage per phase.

## I-005 — MainScreen is highly stateful
Status: OPEN
Impact: home redesign and persistent navigation could become difficult to maintain.
Plan: extract repositories/controllers/models incrementally without forcing a full rewrite.

## I-006 — Temporary cache can consume substantial storage
Status: OPEN
Impact: device storage and network usage.
Plan: configurable bounded cache, LRU/TTL eviction, cache size telemetry, and clear-cache control.

## I-007 — Exact session restoration of remote pages may be impossible when source content changes
Status: OPEN
Plan: persist canonical URL/id plus cached metadata/preview and restore the last known state before background revalidation.

## I-008 — 500 GIF target must be validated on real devices
Status: OPEN
Plan: performance tests around 500 metadata records, large collection lists, tab counts, cache pressure, and scrolling.
