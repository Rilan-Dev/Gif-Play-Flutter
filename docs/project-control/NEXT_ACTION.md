# Next Action

## Current
Phase 0 is complete and accepted. Begin **Phase 1 — Local Media Library & Collection Engine**.

## Immediate implementation sequence
1. Inspect current Flutter package/platform constraints and add the selected Drift/SQLite dependencies.
2. Create the local database bootstrap and schema versioning/migration layer.
3. Implement canonical media identity and MediaRecord persistence.
4. Implement Collection and CollectionItem persistence with reusable empty-list semantics.
5. Implement MediaCacheEntry metadata only; binary cache manager remains Phase 2.
6. Add repository interfaces and Provider-facing integration seams.
7. Migrate existing liked/viewed state into the new media/collection model without destructive loss.
8. Add focused persistence, migration, deduplication, and multi-list tests.
9. Record evidence and update this file for the next Phase 1 slice.

## Product acceptance examples
- Create lists A=50, B=100, C=60.
- Sharing A changes only A's pending queue; B and C are untouched.
- After A is fully shared, A still exists with name/metadata and can receive new GIFs.
- Re-adding the same canonical GIF to a collection does not create duplicate membership.
- Restarting the app retains records and collection definitions.

## Do not do yet
- Do not redesign the entire home screen before the storage contracts are implemented.
- Do not put 500+ records into SharedPreferences.
- Do not store GIF binary payloads in SQLite rows.
- Do not implement the full download/share pipeline until the Phase 1 cache metadata foundation exists.
- Do not replace Provider with another state-management architecture.
