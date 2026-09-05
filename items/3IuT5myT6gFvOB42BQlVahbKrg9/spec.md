## Evidence

Reproduced 2026-09-05 against `cosmic-lua/work` `main` (checkout
`/home/user/work`, `GITBOARD_DIR` pointed at it) and `cosmic-lua/cosmic`
`origin/main`. Sequence, in order:

1. `bin/gitboard show mEBx_YKCA` — item `3IYTD6MmNRrraCeDgg8mEBxYKCA`
   showed `bar: spec: Change is missing or empty` (not pullable), board
   overview showed `todo 202 (0 pullable)`.
2. `bin/gitboard spec mEBx_YKCA <file> --base <file>` — `gitboard-spec:
   3IYTD6Mm's spec replaced`. This adds a `## Change` section; the item
   now carries a `parent:` edge and `priority: band 8, outranks 0` (a
   placed leaf), so nothing else about its bar should be failing.
3. `bin/gitboard show mEBx_YKCA` — no `bar:` line at all: the item's own
   detail view agrees it now passes the bar.
4. `bin/gitboard sync` — `state is current` (a real sync, not skipped:
   only the `lanes` sub-check reported "skipped ... within the 900s
   freshness window", which is the CI-lanes cache, a different
   mechanism from the one below).
5. `bin/gitboard show` (board overview, no ID) — still `todo 202 (0
   pullable)`, and `mEBx_YKCA` still absent from the `[pullable]`-marked
   rows.
6. `bin/gitboard next` — recommended refining a DIFFERENT item
   (`vCsZ_TzIP`) as "the highest-placed todo item that misses the spec
   bar", consistent with the stale 0.
7. `bin/gitboard take mEBx_YKCA` (a direct probe) — succeeded
   immediately: `gitboard-take: 3IYTD6Mm is yours — branch 3IYTD6Mm off
   main`. `take` reads the live board correctly; `show`'s and `next`'s
   pullable computation did not.

This is the second independent recurrence of the same shape: the prior
`/work 9 --routine` pass's own friction log (`friction: 2026-09-05
work9`, item `3IuEiG30`, now closed) recorded an identical
board-summary/`next` vs. `take` disagreement immediately after a `done`
cleared a blocker, and explicitly held it without filing — "needs a
repro from someone with gitboard source access to confirm before
filing as a firm item." This pass has that access (this checkout IS
`cosmic-lua/work`'s own source) and that repro.

Candidate root cause, from reading the source, not yet proven by a
failing test: `_work/gitview.tl:250`'s `list_via_cache` feeds `show`'s
board-overview render from a digest-gated sqlite cache
(`_work/cache.tl:196`'s `open`) — a cache hit requires
`cachedb.meta_get(db, "refs_digest")` to equal a freshly computed
digest of `refs/heads/items|ended|board` (`_work/cachedb.tl:102`,
`WATCH_PATTERNS`). `_work/gitspec.tl` (the `spec` verb) commits the new
spec straight to the item's `refs/heads/items/<id>` branch and does
NOT touch the cache file at all — no invalidation, no incremental
patch (`grep -n "cache" _work/gitspec.tl` finds nothing). That is fine
BY DESIGN per `_work/cache.tl:181-189`'s own doc comment ("a hand-moved
ref (digest mismatch) ... take[s] the same path: wipe ... and
rebuild") — the NEXT `open()` call should see the changed ref SHA,
fail the digest match, and rebuild. It did not, across a `sync` and
two `show`s. Two places worth checking first: whether
`refs.for_each_ref` (used both to seed `known_digest` in
`list_via_cache` and inside `cachedb.fresh_digest`) is reading the same
`root` the `spec` commit was written to, and whether `take`'s own code
path (`_work/gitspec.tl` or a sibling) forces a rebuild that `show`'s
path does not — since `take` on the same item, moments later, saw the
current state correctly.

## Non-goals

Not a claim that `sync`'s own "lanes: skipped ... freshness window"
behavior (CI check-run observations) is related — that is a separate,
intentional cache with its own 900s TTL and is working as documented;
this item is about the item-graph cache (`_work/cache.tl`,
`_work/gitview.tl`), which is supposed to be digest-exact, not
time-windowed.

## Impact

An orchestrator (human or automated `--routine` pass) that trusts
`show`'s pullable count or `next`'s single recommendation right after
refining an item's spec will see no pullable work and either stop
early or spend a refine/investigation cycle on a wall, exactly as the
prior pass's friction log describes (~9 tool calls lost there). The
correct workaround in the meantime, worth stating in `gitboard help
orchestrate` or `help bar` once this is confirmed: after writing a
spec that should newly pass the bar, probe with `take ID` directly
rather than trusting the board-overview count or `next`.
