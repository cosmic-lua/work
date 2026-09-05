## Access

read access to `cosmic-lua/work` — `_work/ciobs_test.tl`, `_work/store.tl`,
`_work/storewrite.tl` and commit `fd6f1dc0` cited below in Evidence.

## Evidence

`main` is currently broken for every PR touching `_work/*`: `_work/ciobs_test.tl`
calls `store.save(...)` at two call sites, but `save` moved from `_work/store.tl`
to `_work/storewrite.tl` (as `storewrite.save`) in the recent write/read split,
commit `fd6f1dc0` ("Split store.tl's write half into storewrite.tl", merged to
main). Confirmed independently on a clean, unmodified checkout of `main`
(builder of `«T6Gj_9ge9»`, PR #24, stashed their own diff first) and on PR #24's
CI itself (`bin/cosmic --check types _work/ciobs_test.tl` / the `ci` GitHub check,
2026-09-05):

    _work/ciobs_test.tl:156:18: error: invalid key 'save' in record 'store' of type record store
    _work/ciobs_test.tl:169:18: error: invalid key 'save' in record 'store' of type record store
    cosmic -c: compile-batch: 1 of 118 failed
    ci: FAIL (check coverage)

`grep -n "store\.save\|storewrite" _work/ciobs_test.tl` shows both call sites
still reference `store.save` and the file does not require `_work.storewrite`
at all. Every other caller of the moved function already requires
`_work.storewrite` (`grep -rln "storewrite.save" _work/*.tl`) — `ciobs_test.tl`
is the one site the split missed.

## Change

`_work/ciobs_test.tl`: add `local storewrite = require("_work.storewrite")`
alongside the file's existing requires, and change both call sites (lines 156
and 169) from `store.save(...)` to `storewrite.save(...)`, with no other
argument changes — `storewrite.save`'s signature is unchanged from `store.save`'s
(the split moved the function, it did not reshape it; confirm via
`grep -n "^local function save" _work/storewrite.tl` before editing, in case the
signature shifted since `fd6f1dc0`). No other file changes.

## Non-goals

Re-examining the rest of the store/storewrite split (`fd6f1dc0`) for other
missed call sites — `grep -rln "store\.save\b" _work/*.tl` before editing to
confirm `ciobs_test.tl` is the only remaining one; if it is not, report the
others as an out-of-scope finding rather than fixing them here. Any other
change to `_work/ciobs_test.tl` beyond the two call sites and the new require.
