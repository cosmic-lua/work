## Evidence

Two loose ends the review of cosmic-lua/work#22 («GkFk_U7L5») recorded as
non-blocking, 2026-09-05:

1. An ambiguous handle is refused with two different listings depending on
   which path answered: `_work/cachequery.tl:145` (`resolve_tail`, the cache
   path) lists case-folded TAILS (`id:sub(20)`), while `_work/tail.tl:182`
   and `:209` (`resolve_glob`, both branches) list FULL 27-character ids. The
   `"%s is ambiguous: %s"` template is the same; the operands differ by
   implementation accident. Unobservable today (tails are collision-free on
   the live board: `git for-each-ref --format='%(refname)' refs/heads/items
   refs/heads/ended | sed 's#.*/##' | rev | cut -c1-8 | rev | sort | uniq -d
   | wc -l` → 0) but a real inconsistency.
2. `tail.resolve` (the in-memory resolver over a loaded item list) has no
   non-test caller after #22 (`grep -rn "tail\.resolve(" _work cmd | grep -v
   _test` → nothing); it survives on its own unit tests.
3. `test_resolve_glob_skips_the_fallback_for_an_all_digit_tail`
   (`_work/tail_test.tl`) asserts only the refusal, not that the fallback
   `for-each-ref` was skipped; a regression that removed the skip would pass.

## Change

1. One listing for an ambiguous handle: both paths render the candidates as
   handles (`tail.handle(id)`, the form the user typed and the board
   prints), in id order; the template stays `"%s is ambiguous: %s"`.
   `_work/tail_test.tl` and `_work/cachequery_test.tl`'s ambiguity cases
   assert the identical rendering.
2. Delete `tail.resolve` and its tests; if `resolve_glob`'s case-folded
   fallback reuses any of its matching logic, keep that as a private helper.
3. The all-digit test counts `refs.for_each_ref` calls through a module-table
   stub and asserts exactly the exact-glob call, none for the fallback.

## Non-goals

Changing the handle format; changing any other refusal string; the cache
schema (a `sha` column that would let a cache hit carry a lease is its own
question, not this one).
