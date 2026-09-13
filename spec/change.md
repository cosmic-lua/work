Read `_make/testrun.tl`, `_make/init.tl`, `embed/cosmic.mk`, and
`_make/graph.tl` together and determine, with a clean reproduction (not
just re-reading the review's claims):

1. Does `testrun_dep` alone already invalidate a spawned-binary test's
   `.got` record on any engine rebuild, repo-wide, today?
2. If yes: is #1636's fix (see Evidence — a positional, by-directory
   `deps_<stem>` addition in `_make/graph.tl`, not a per-file `---
   reads:` header) redundant, harmless-but-unnecessary, or does it
   serve a distinct purpose worth keeping anyway?
3. If no (testrun_dep does NOT already cover this): explain why the
   review's mutation test (guard disabled, staleness bug still "fixed
   itself") happened anyway — is there a different confound?

Record the finding as this item's resolution. If the premise is
confirmed false (testrun_dep already handles it), #1636 should be
reworked to either drop its now-redundant change or explain the
distinct value it adds, and `1XDh_5npx` (the ~20-file audit) should be
re-scoped or dropped once the premise is settled.
