# GIF Play Flutter — Research Protocol

## Purpose

This file defines how future AI-assisted development should research this repository quickly and consistently.

## Authority

- Repository: `Rilan-Dev/Gif-Play-Flutter`
- Default branch: `main`
- Current index baseline: `9a0c17c973a60b0e74aac4d6efc6f047f592f217`
- Primary index: `docs/AI_REPO_INDEX.md`

## Before implementation

1. Read `docs/AI_REPO_INDEX.md`.
2. Locate the feature's entry screen.
3. Trace the feature's data service/actions.
4. Trace the relevant models.
5. Trace providers/persistence if state crosses screens or restarts.
6. Trace shared widgets before creating new widgets.
7. Check platform implications for Android/iOS/Web.
8. Inspect existing tests and add focused coverage.

## Search priority

Use this order unless the feature clearly points elsewhere:

```
Feature screen
  -> feature actions
  -> feature data service
  -> model
  -> provider
  -> shared widget
  -> utility
  -> platform integration
```

## Current architectural boundary

The repository has two important media representations:

- `MediaItem`: active feed/scraping/display path.
- `GifItem`: GIF detail/viewer/service/persistence-oriented path.

Do not silently merge these types during feature work. First determine whether the feature belongs to the feed path, GIF path, or both.

## Current backend boundary

The active main feed is HTML scraping through:
`MainScreenDataService.fetchData()`.

The generic `GifService` is currently placeholder code.

When replacing or improving the backend:
- introduce a clear repository/service contract;
- keep HTML parsing isolated;
- make failures explicit;
- avoid coupling widgets to HTTP;
- retain compatibility with existing providers and views where practical.

## Testing policy

The existing smoke test is not meaningful application coverage.

For each feature, prioritize tests for:
- model behavior;
- parsing/service behavior;
- provider state transitions;
- navigation;
- critical user actions;
- error/empty/loading states.

## Index maintenance

Update `docs/AI_REPO_INDEX.md` when:
- a new feature area is introduced;
- files move between architectural layers;
- a new service/provider/repository is introduced;
- a backend source changes;
- state management changes;
- the media model contract changes;
- platform-specific capabilities change.

Do not update the index for every trivial styling-only edit.

## Fast investigation examples

- Feed performance -> main screen + media widgets + cached image widget + data service.
- Better search -> search screen + main feed filter + media model + data service.
- Favorites redesign -> liked provider + persistence + liked screen + media identity.
- Viewer controls -> gif viewer directory + GIF detail + GIF model + data service.
- Sharing -> download/share utilities + file utils + share screen + platform manifests.
- New layout -> view mode enum/provider/selector/switcher + layout implementations.
