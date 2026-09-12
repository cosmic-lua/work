## Evidence

`_work/ghwrite_test.tl` stubs and restores `GITHUB_TOKEN` around its cases —
`stub_token()`/`restore_token(prior)` (defined at lines 13-28), 29 matching
call sites across the file:

    $ grep -c "stub_token\|restore_token" _work/ghwrite_test.tl
    29

Nothing under test reads that variable. `_work/api.tl`'s codec never
inspects the environment at all — it holds an injected `M.transport` bound
to a local refusal, and `_work/network_boundary_test.tl` asserts that
`api.tl` neither requires `cosmic.env` nor mentions `GITHUB_TOKEN`/
`GH_TOKEN`. The credential read those stubs were written against was
removed in "Redesign gitboard around caller-owned Git transport"
(`ae840934`, PR #90); the stubs were left behind.

Noticed while building `BM00_etFW` (the caller-named provider-transport
opt-in), where the contrast is the point: that item's own tests pass a
fake reader rather than touching the real environment, precisely because
nothing in the codec consults it. A test that still stubs a credential
variable implies the opposite to the next reader.

## Change

Remove `stub_token`/`restore_token` and their call sites from
`_work/ghwrite_test.tl`, along with the now-unused `cosmic.env` import if
nothing else in the file uses it. The cases themselves keep their existing
fake-transport setup and assertions unchanged — this removes scaffolding,
not coverage.

Confirm the file still passes on its own (`bin/cosmic --make test
_work/ghwrite_test.tl`) before and after, and that the removal is the only
behavioural difference: same case count, same assertions.

## Non-goals

Not touching `_work/ghwrite.tl` itself, and not changing what any case
asserts. Not auditing other `*_test.tl` files for the same vestigial
pattern — if this turns out to be more widespread, that is its own sweep
item with its own stated pattern and count.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
