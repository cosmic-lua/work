## Evidence

`/work 9 --routine` pass, 2026-09-04: three pullable todo items in a row
(«lER0_dvnI», «4CTF_fCZV», «gj7P_Db0H» — full ids `3IqbI4UfMN43L4amsqjlER0dvnI`,
`3IreoUxF37RMye0hRHQ4CTFfCZV`, `3IrflVHkVANAEXavtyTgj7PDb0H`) had no `base`
field set and no `set ... base` commit in their history, unlike sibling
items filed the same day that DO set it (e.g. «WQjH_vI9p», «5Ipy_1v4A», both
carrying an explicit `set ... base` commit right after `new`). All three
specs are scoped entirely to `_work/*.tl` — the gitboard tool's own source,
which exists ONLY on the `board` branch of `cosmic-lua/cosmic`:

    $ git clone --depth 1 --branch main https://github.com/cosmic-lua/cosmic main-check
    $ ls main-check/_work
    ls: cannot access 'main-check/_work': No such file or directory

`gitboard take` on each of the three (before repair) resolved the item's
unset base to `main` — confirmed live: `bin/gitboard take lER0_dvnI
--session build-lER0_dvnI-62aa6405` printed `branch 3IqbI4Uf off board` only
AFTER `bin/gitboard set lER0_dvnI --base board` was run; before the repair,
`bin/gitboard brief builder 4CTF_fCZV` (before I fixed it) emitted a brief
whose step 8 read `Open a PR from 3IreoUxF to main` — a builder following
it literally would have branched off `main`, found no `_work/` tree at
all, and been unable to make any progress on a spec entirely about files
that branch doesn't have.

Root cause, read from source: `_work/gitgraph.tl`'s `cmd_new` (lines 47-118)
takes `title`, `parent`, `spec`, `repo`, `force`, `why` — no `base`
parameter at all. The constructed `item.Item` record (lines 82-87) has no
`base` field, so a freshly filed item's base is whatever empty/default
value the store falls back to (observed as `main` at `take`/`brief` time).
The ONLY way to set `base` is a second, separate call — `gitboard set ID
--base BRANCH` (`_work/gitverbs.tl`) — after `new`. Nothing at file time
prompts for it or warns it was skipped; three items in one day is not
a one-off slip.

## Change

`_work/gitgraph.tl`: add an optional `base` parameter to `cmd_new`
(same position/shape as the existing `repo` parameter — nil/empty means
"unset, inherits today's fallback behavior") and thread it into the
constructed `item.Item` record (currently built at lines 82-87 with no
`base` field). `_work/gitboard.tl` (the CLI dispatcher, wherever it maps
`new`'s flags — grep `--repo` in the `new` command's flag parsing for the
existing pattern to mirror): add a `--base BRANCH` flag alongside the
existing `--repo OWNER/NAME`, so `gitboard new TITLE --parent ID --repo
OWNER/NAME --base BRANCH --spec-file FILE` files a correctly-based item in
one call instead of two.

`_work/gitgraph_test.tl` (or wherever «T6Gj_9ge9`'s split lands it —
check `_work/gitgraph_test.tl`'s current line count first with `wc -l`;
it was exactly 500/500 as of this writing and «T6Gj_9ge9» is already
in flight splitting it, so a fresh `wc -l` may show headroom in a
successor file instead): a new item filed with `--base` set carries that
exact base with no follow-up `set` call; a new item filed without `--base`
keeps today's exact fallback behavior unchanged (this Change adds an
option, it does not change the default).

## Non-goals

Not a validation/refusal for a base that doesn't contain the spec's
named paths (a "does this branch actually have `_work/foo.tl`" check) —
that is a heavier, separate mechanism (parsing spec prose for paths,
resolving them against a branch listing) worth its own item if this
narrower fix does not fully close the gap. This item only removes the
two-step, easy-to-forget pattern by letting `--base` be set at `new`
time, same as `--repo` already can be.
