## Evidence

`next` is network-bound the moment any item sits in review. Profiled
2026-09-05 against the live board by wrapping module functions with timers
and running `_work.gitboard.main("next")` in-process (script kept with the
profile: `bin/cosmic prof.lua next`): total 1,340 ms, of which
`_work.gh.head_checks` was 1,139 ms in ONE call; the whole-board load was
125 ms and everything else under 10 ms each. `show` on the same board, which
does not read CI, was 233 ms. Measured from the shell the same minute:
`next` best-of-three 0.937 s, `show` 0.194 s.

The call is `_work/gitview.tl:59` `ci_states`: one `gh.head_checks(s, i.pr,
i.repo)` per open review-stage item with a PR, every render, with no cache
between renders — `grep -n "cache\|etag\|fresh" _work/gh.tl` matches nothing.
At three items in review that is three sequential GitHub round trips through
the session proxy, 3–4 s, on the verb every orchestrator loop starts with.
The lanes observation already solved the same shape: `_work/lanes.tl`
records the last observation with `FRESH_WINDOW_S = 15 * 60` (line 44),
`GITBOARD_LANES_FRESH` (line 49) to override, and `sync` reuses it inside
the window (`gitboard-sync: lanes: skipped (observed 444s ago, within the
900s freshness window)`), stored in the cache database's `lanes` table
(cosmic-lua/work#5).

## Change

CI state becomes an observation with a freshness window, like lanes, read
by `next`/`show` from the cache and refreshed at most once per window.

1. `_work/cachedb.tl` schema: a `ci_checks` table, STRICT, WITHOUT ROWID:
   `pr INTEGER NOT NULL, repo TEXT NOT NULL, head TEXT NOT NULL, state TEXT
   NOT NULL CHECK (state IN (<the values gh.head_checks returns — read its
   record and pin them>)), observed_at INTEGER NOT NULL, PRIMARY KEY (repo,
   pr)`. Bumping the schema is the fingerprint's job (#14); no hand version.
2. `_work/gh.tl`: `head_checks` unchanged (it stays the live read).
   A new `_work/ciobs.tl` (name it beside `lanes.tl`) owns the observation:
   `read(c, repo, pr) -> state | nil, age_s`, `observe(s, c, repo, pr)`
   which calls `head_checks` and upserts the row, and `fresh(age_s)` using
   the same window constant and an env override `GITBOARD_CI_FRESH`,
   sharing the constant with lanes rather than copying it (move
   `FRESH_WINDOW_S` to one place both require).
3. `_work/gitview.tl` `ci_states`: for each candidate, read the observation;
   when absent or older than the window, `observe` (one live call) — so a
   render pays the network at most once per item per window, and a hot
   loop pays nothing. The row records the `head` it observed; a render
   cannot learn the CURRENT head without the live call the window exists to
   bound, so a pushed head is NOT detected by the render — a row may lag
   a push by up to the window, and the module header says so in one
   sentence. What keeps that lag out of the flow's decisions is 5 below.
5. Write-through from the deciding verbs: `take --pr` (the verb a builder
   runs after every push, `_work/gitverbs.tl:~118`) and any other verb that
   calls `gh.head_checks` live keep their live read AND upsert its result
   into `ci_checks` through `ciobs.observe`'s write path, so the row is
   fresh again the moment the flow learns of a new head. `sync` refreshes
   every review-stage item's observation the way it refreshes lanes, so a
   loop that syncs first never blocks `next` on GitHub at all.
4. (folded into 5.)
6. Tests: a `_work/ciobs_test.tl` with `gh.head_checks` swapped for a
   counting stub on the module table: two renders inside the window make
   one call; `GITBOARD_CI_FRESH=0` makes one per render; a `take --pr`
   with the live stub returning a new state leaves the row showing that
   state and head with no further call from the next render. Expected for the builder's own check: `next` on a board with
   review items within a second of `show`.

## Non-goals

Caching `head_checks` for the deciding verbs; changing the `gitboard-next:`
output; the whole-board load's own cost (the cache-served reads item
«BZCt_Z5l7»).
