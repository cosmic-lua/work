All on the `board` branch (`_work/**`), landed as a PR whose base is
`board`; gate with `bin/cosmic --make ci` in the board worktree.

1. **`_work/action.tl`** — remove the rework carve-out: drop
   `and not is_rework(i)` from the hold conditions at `:105`
   (`unheld`) and `:127` (`held_names`). A live-claimed item is held
   from other sessions whether or not a verdict stands on it; a stale
   one is offered, as today. Rewrite the `:61–64` comment: the lease
   bounds how long rework can strand on a dead session, and a LIVE
   claim over rework is the builder mid-loop, not a lock nobody
   released.
2. **`_work/action.tl:255–271`** — the `whose` guidance collapses:
   an offered item claimed by another session is now, by
   construction, stale — one takeover message, carrying everything
   the guard will demand:
   `(rework of X's build; claim stale Nh — take it over: move it with
   --claim <you> --force --why <reason>)`, with the "rework of X's
   build; " prefix only when `is_rework`. The separate live-rework
   branch at `:257–263` is deleted.
3. **`_work/action_test.tl`** — two tests: a rework item with a LIVE
   foreign claim is held (`next` skips it and counts it held); a
   rework item with a stale claim is offered and the guidance names
   `--force`. Follow the file's existing fixture style.
4. **Rejected, recorded here**: reading PR-branch pushes as claim
   keepalive. Reads are network-free by design (`README.md`: "Reads
   need no network and no token"), and with the carve-out gone the
   live-claim race it would have papered over no longer exists; the
   lease alone decides. If 4h proves slow for dead-session rework,
   the flow review retunes `LEASE_S` — it does not re-grow the
   carve-out.
