Re-examining the rest of the store/storewrite split (`fd6f1dc0`) for other
missed call sites — `grep -rln "store\.save\b" _work/*.tl` before editing to
confirm `ciobs_test.tl` is the only remaining one; if it is not, report the
others as an out-of-scope finding rather than fixing them here. Any other
change to `_work/ciobs_test.tl` beyond the two call sites and the new require.
