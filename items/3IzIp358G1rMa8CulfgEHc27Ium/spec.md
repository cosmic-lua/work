## Evidence

PR #1791 (item «wAe5_evHa») replaced the "generic T" and "binding constant
by name" kinds' explicit-residual entries in `_build/casts_kinds.tl` with
scoped patterns. `docs/design/casts.md`'s prose for both kinds still
describes the old mechanism: the "generic T" section (around line 292)
still says the `cosmic/fs/walk.tl` site is "named explicitly," and the
"binding constant by name" section (around line 411) still says "one site
named explicitly in `_build/casts_kinds.tl`" — both now inaccurate. No gate
catches this: `_cli/citations.tl`'s checker only verifies fenced
`-- path:line` code-block quotes, and neither section carries one for
these sites, so the drift is silent.

## Change

Update both sections of `docs/design/casts.md` to describe the current
pattern-scoped mechanism instead of "named explicitly," matching how
`_build/casts_kinds.tl`'s header already documents the two-entries-same-
name shape for "generic T."

## Non-goals

No change to `_build/casts_kinds.tl` or `_build/casts_test.tl` — the
allowlist mechanism itself is correct and gated; this is a docs-only fix.
