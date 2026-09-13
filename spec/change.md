In `_work/brief.tl`, at line 301, replace `gh.slug(s, it.repo)` with a
resolution that defaults an unset `it.repo` to `product.REPO` (already
imported or importable as `_work.product`) instead of the checkout's
own `origin`: when `it.repo` is `""`, use `product.REPO` directly
(never call `gh.slug`, which stays reserved for the board's-own-PR
gates that already call it correctly at lines 167 and 207); when
`it.repo` is set, keep using it verbatim as today. The `BASE_BRANCH`
branching just below (lines 304-309, `repo:find("cosmopolitan", ...)`)
is unaffected — it already works off whichever `repo` string it's
handed.

Add a test to `_work/brief_test.tl` asserting that `brief` for an item
with `repo = ""` fills `<REPO>` with `product.REPO`
(`"cosmic-lua/cosmic"`), not the test store's own checkout origin —
the exact regression this item closes — alongside the existing
covered case (an item with `repo` set renders that repo verbatim).

Gate with the repo's own test runner for `_work/**`.
