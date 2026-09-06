## Evidence

The builder brief's step 3 names the ratchets a diff can trip —
`grep -n 'ratchet' _work/brieftext.tl` → 61-66: "casts, nil-returns,
cast-sites, coverage rows, doc paths" — and none of the three a NEW
PUBLIC `cosmic.<name>` module trips. This pass (2026-09-06) the
`cosmic --find` PR 1763 went red in CI twice on exactly those:
`test_every_public_module_has_example_or_waiver` (no
`cosmic/ast/init_example.tl`), then `_build/doc_returns_test`
(`@return` tags per slot, only checked once the module is public);
its builder had also hit `_build/public_surface_baseline.tl` locally.
Three CI rounds, ~10 min each, and the orchestrator's env note now
carries the list by hand on every cosmic brief. Two more hand-carried
lines: `--make coverage` after the LAST test edit (a `total` moves
when a test is added — PR 1763's first row was wrong), and
`--make build` once before `--check types` on a file whose sibling
moved (the checker reads the last build's snapshot — AGENTS.md
Testing states it; the brief does not).

## Change

`_work/brieftext.tl`, builder template step 3, one sentence after the
ratchet list: "A new public `cosmic.<name>` module trips three more:
`_build/public_surface_baseline.tl` (`--make run
_build/public_surface.tl --baseline`), the example ratchet (a
runnable `<name>/init_example.tl` or `<name>_example.tl`), and
`_build/doc_returns_test` (one `@return` tag per declared slot on
every function it exports)." And, same step: "Run `--make coverage`
after your last test edit, not before — a new test moves a row's
`total`; run `--make build` once before `--check types` on a file
whose sibling you moved." `_work/brieftext_test.tl`: the builder
template contains "public_surface" and "after your last test edit".

## Non-goals

No change to the review template; no new ratchet.
