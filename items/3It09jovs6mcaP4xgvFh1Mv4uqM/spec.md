## Evidence

Nothing in gitboard's own code ever packs a local checkout: `grep -rn
'"gc"\|gc --auto\|repack' _work/*.tl` (excluding `_test.tl`) on
2026-09-05 against `cosmic-lua/work`'s `main` — 0 hits. Every write goes
through raw plumbing (`_work/store.tl`'s `GIT_DEFAULTS`, `git -c
core.createObject=rename ...`) or `git fast-import`
(`_work/fastimport.tl`), never a porcelain command that would trip git's
own `gc.auto` loose-object threshold on its own.

Reproduced the effect directly: a fresh `gitboard init --dir` sandbox, no
network, filing 1,600 items through ordinary `new`/`spec`/`compare` calls
with no `git gc` ever run — `git count-objects -v` afterward: `count:
9615, in-pack: 0, packs: 0`. Timed `show`/`next` before and after one
`git gc --aggressive` on the SAME board (no item added or removed,
`git count-objects -v` after: `in-pack: 9615, packs: 1`):

  show: 1.106s -> 0.365s  (3.0x)
  next: 0.692s -> 0.392s  (1.8x)

For comparison, this session's live `o/board` clone (freshly cloned this
session, 922 items) currently shows `count: 0, in-pack: 48875, packs: 1`
— fully packed, because a fresh `git clone` always receives one packfile
from the server. That says nothing about a long-lived LOCAL checkout: the
bootstrap in `skills/work/SKILL.md` clones `o/board` once per checkout,
then reuses it indefinitely via `sync`, so every local mutation before its
next push (and, more importantly, every object a `sync`/fetch pulls down
locally over the checkout's life) accumulates as loose objects with
nothing in gitboard itself ever consolidating them. Git's own `gc.auto`
default (~6,700 loose objects) may never trip at all if no porcelain
command that checks it runs against this checkout in the meantime.

## Change

Decide whether gitboard should opportunistically keep its own local
checkout packed, given it already knows exactly when it is safe and cheap
to check.

1. Measure how many loose objects a realistic long session actually
   accumulates locally (a day of orchestrator activity: dozens of
   `new`/`take`/`spec`/`verdict`/`done` calls) against `cosmic-lua/work`'s
   real object growth rate, to size whether this is a today problem or a
   months-from-now one.
2. If worth doing: `_work/store.tl` or `_work/publish.tl` — after a
   successful `sync` or `publish` (the two points where the checkout is
   known to be in a clean, referenced-consistent state), run `git gc
   --auto` (respects git's own threshold, so it is a no-op most of the
   time and only does real work once the checkout has actually earned it)
   rather than an unconditional `gc`.
3. Non-blocking: this must never add meaningful latency to an ordinary
   verb's fast path — measure `gc --auto`'s cost on an already-packed
   repository (expected: a single loose-object count check, no full gc)
   before landing this anywhere near `new`/`take`/`spec`.
4. Tests: a `_work/store_test.tl` (or `publish_test.tl`) case that a
   checkout with loose objects below git's threshold triggers no
   detectable extra work, and one with loose objects pushed artificially
   above it (or with the threshold lowered via `-c gc.auto=N` for the
   test) does get packed by the next `sync`/`publish`.

## Non-goals

Fixing any specific verb's algorithm (`fsck`'s per-item git calls are
filed separately as «5k6U_43IK»); the SQL-views seam («BZCt_Z5l7»);
running a full `git gc` (not `--auto`) anywhere in the hot path; touching
the real `cosmic-lua/work` clone's current packed state, which is fine
today and not itself evidence of a problem.
