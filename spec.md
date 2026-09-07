## Evidence

See the parent outcome («AP77_4XCs») for the full evidence trail.
`_work/gitworktree.tl:121-125` (`default_base`) matches on
`repo:find("cosmopolitan", ...)` for its base-branch default;
`:137-151` (`bootstrap`) detects a cosmic tree by `bin/cosmic`'s
presence and then hardcodes `{"bin/cosmic", "--make", "fetch"}` /
`{"bin/cosmic", "--make", "build"}` directly, with a second hardcoded
branch for a cosmopolitan tree (nothing to run) and a third for
anything else (also nothing, tree "unrecognized"). Adding, say, a
`cosmic-lua/cosmopolitan`-adjacent repo with its own bootstrap step
today means editing this function and shipping a new gitboard, not a
change the product repo itself can make.

Depends on the sibling item («oJ31_ppvR», the repo-mechanics resolver)
landing first — this item is the resolver's first real caller.

## Change

`_work/gitworktree.tl`'s `bootstrap()`: once «oJ31_ppvR»'s resolver is
available, resolve the worktree's own kind first. A `cosmic` kind runs
`{"bin/cosmic","--make","fetch"}` then `{"bin/cosmic","--make","build"}`
exactly as today (streamed, not captured — unchanged from the
already-landed quiet-mode item `YLxi_6fmt`) and returns `"cosmic (fetch
+ build)"`. A `make` kind runs its resolved `bootstrap` command when the
resolver found one, or reports `"nothing needed"` when the target
doesn't exist — this generalizes today's cosmopolitan-specific
`third_party/lua`-presence branch to any `make`-kind repo with no
bootstrap step. An absent resolution keeps today's `"nothing
(unrecognized tree)"`, unchanged.

`default_base`: try the resolver's git-based default
(`origin/HEAD`) first; when that comes back `""` (a shallow clone, or a
remote that doesn't report one), fall back to today's
`repo:find("cosmopolitan", ...)` string match, then `"main"`. The
item's own `base` field, already checked by the caller before
`default_base` is ever reached, continues to win over all of this —
unchanged.

Tests: a fixture tree with `bin/cosmic` present, asserting the cosmic
bootstrap commands and description; a fixture tree with a `Makefile`
exposing a `bootstrap` target, asserting that command runs instead; a
fixture `Makefile` with no `bootstrap` target, asserting `"nothing
needed"`; a fixture with neither, asserting today's `"nothing
(unrecognized tree)"` is unchanged; a fixture whose git remote reports a
default branch, asserting `default_base` honors it over the repo-name
heuristic; a fixture with no reportable default branch, asserting the
`repo:find`/`"main"` fallback chain is exactly as it is today
(regression guard).

## Non-goals

Not adding the real `bootstrap`/`gate`/`check-file`/`test-file` targets
to `cosmic-lua/cosmopolitan`'s own Makefile in this item — it lands the
caller and proves it against a fixture; wiring cosmopolitan's actual
Makefile is each repo's own follow-on once this and the sibling
brief-template item are both in place. Not changing what `bootstrap()`'s
verdict line looks like for the unrecognized-tree path.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
