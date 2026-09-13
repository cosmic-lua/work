`_work/gitverbs.tl` (or the module holding `cmd_new` — `git grep -n
'local function cmd_new'` places it): after the item is written,
`new` runs `gitready.ready_problems` on it and prints each problem as
a `bar:` line under its verdict line, exactly as `show` renders them
— the item still files (a container or an evidence-only item is
legitimately barred), so this is a report, not a refusal.
`_work/gitnew_test.tl`: a spec reaching a repo with no `## Access` →
the `bar:` line appears in `new`'s output; a passing spec → none.
