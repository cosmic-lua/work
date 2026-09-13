Once `bin/cosmic --make fetch` picks up a cosmos pin built from a
cosmopolitan release carrying PR #315 (`3p/cosmos/cosmos_pin.tl`
version + sha256 bump), in the same PR:

1. Rewrite `cosmic/time.tl:83`'s `sleep_remaining_ms` to destructure
   the new shape: a `remaining` table on success/non-EINTR-failure
   position, and a fourth `eintr_remaining` table only present on the
   EINTR branch. Preserve `sleep_remaining_ms`'s own existing contract
   (`integer | nil, string` — the internal millisecond-remainder
   engine, per its own comment: "reports the remainder in MILLISECONDS
   because a (secs, nanos) pair would push the error into slot 3, out
   of `local v, err`'s reach") — only the INTERNAL destructuring of
   `unix.nanosleep`'s return values changes; the function's own public
   shape does not need to.
2. Re-run `bin/cosmic --make ci` and confirm `cosmic/time_test.tl` (if
   it exercises `sleep_remaining_ms`/`sleep_ms` directly — check) still
   passes; add coverage for the EINTR path if none exists today.
3. Confirm no other `cosmic/*.tl` file calls `unix.nanosleep` directly
   (`grep -rn 'unix\.nanosleep\|cosmo\.unix\.nanosleep' cosmic/` at
   pickup time — re-run rather than trust this item's own grep, since
   the tree will have moved).
