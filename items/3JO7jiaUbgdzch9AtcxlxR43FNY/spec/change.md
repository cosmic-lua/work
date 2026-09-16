`--fetch`'s documented meaning is now false in two places. Both say it
authorises acquisition ON A MISS; after «sYow_SyfM» it forces acquisition
regardless of hit or miss, because the cache scan is skipped entirely when
`fetch` is set.

Verified 2026-09-16 against `d7d1e1606`, neither file touched by that diff:

- `_work/gitcommands.tl:277` — `{long = "fetch", help = "allow pinned
  runtime download on cache miss and product dependency fetch"}`
- `_work/gitworktree.tl:12-13` — "Pinned cosmic targets use private verified
  runtime snapshots; `--fetch` explicitly authorizes acquisition on a miss
  and dependency fetching."

`_work/gitcommands.tl:377`'s `{long = "fetch", help = "passed to
`worktree --fetch`"}` is a pass-through and stays correct by reference; it
needs no edit if the two above are fixed.

Restate both to what the code does: `--fetch` acquires the pinned runtime
even when a cached one is present and verified, and a missing or rejected
cache now acquires without it.

State the consequence too, because it is the part a caller can be surprised
by: with `--fetch`, a machine that is offline but holds a cryptographically
verified cache will now fail where it previously succeeded. The cache check
is a digest match against the exact pin (`_work/worktree_runtime.tl:100-105`),
so the skipped hit was byte-identical to what the download produces — the
flag trades that for an unconditional round trip, which is what "explicit
acquisition" now means.

Regression: the `--fetch` help string and the module doc comment are
asserted against the behaviour, or the behaviour's own test names them, so
the two cannot drift apart again silently. A doc-only change with no guard
will rot the same way this one did.
