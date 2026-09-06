## Evidence

Twice this pass `gitboard new --spec-file` accepted a spec that
`take` then refused on the bar — «40VG_JWAD» and «J0zb_occu», both
"spec reaches cosmic-lua/work with no declared read access — name it
under ## Access" — one round trip each (`new`, `take` refused, `spec`,
`take`). `new` runs no bar check: `git grep -n 'ready_problems' --
_work/gitnew*.tl _work/gitverbs.tl` → only `cmd_take`'s call at
`_work/gitverbs.tl:199`; `show` renders the same list.

## Change

`_work/gitverbs.tl` (or the module holding `cmd_new` — `git grep -n
'local function cmd_new'` places it): after the item is written,
`new` runs `gitready.ready_problems` on it and prints each problem as
a `bar:` line under its verdict line, exactly as `show` renders them
— the item still files (a container or an evidence-only item is
legitimately barred), so this is a report, not a refusal.
`_work/gitnew_test.tl`: a spec reaching a repo with no `## Access` →
the `bar:` line appears in `new`'s output; a passing spec → none.

## Non-goals

No refusal at `new`; no change to what the bar checks.
