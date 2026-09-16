`gitboard worktree ID` fails on a cold runtime cache and only then names the
flags that would have worked. Measured: 4 of 4 worktrees created in one
session failed the first call, each with

    gitboard-worktree: checkout created at <dir>; preparation failed: no
    verified runtime for sha256 dd6b44b0…; use --fetch for explicit
    acquisition; recovery: gitboard worktree "<id>" --adopt "<dir>"
    --receipt-out FILE

and each then needed the four-flag recovery. The checkout IS created; only
preparation fails, so the retry must adopt what the first call left behind.

`--fetch` is not in `gitboard help worktree`'s option list as the flag a first
run on a fresh machine needs; nothing lets a caller predict the failure.

The change is in `_work/worktree_runtime.tl`, inside `prepare()`. An earlier
revision of this spec named `_work/gitworktree.tl` and gave a grep against it;
that is WRONG and cost a builder six tool calls before it bounced. Verified
2026-09-16 at `28e4d582c`: `grep -n "no verified runtime for sha256"
_work/gitworktree.tl` returns nothing. `gitworktree.tl` only calls through
(`runtime.prepare(c.source, path, pin, fetch, verbose)`, `:214`), wraps
whatever error comes back (`checkout created at %s; preparation failed: %s`,
`:295`) and appends the `--adopt` recovery hint (`:398`). The quoted failure
text above is those two files' output concatenated, which is what misled the
earlier revision.

The acquisition logic is all in `prepare()`:

- the cache-scan loop over `o/bootstrap/cosmic{,.ape}` under both root and
  source, `_work/worktree_runtime.tl:300-306`;
- the refusal, `:307-309`.

Two changes, both there:

1. Acquire the runtime when it is absent, rather than refusing: delete the
   early return at `:307-309` so a missing verified runtime takes the same
   acquisition path `--fetch` takes today.
2. `--fetch` keeps a meaning: "acquire even if a cached runtime looks
   usable". That requires the cache-scan loop at `:300-306` to be skipped
   when `fetch` is true — the loop and its `verified()` calls are private to
   `prepare()`, so this cannot be expressed by transforming the boolean at
   the call site.

`_work/worktree_runtime_test.tl:95`,
`test_missing_corrupt_symlink_cache_never_executes_or_downloads_without_fetch`,
locks in exactly the behaviour change 1 inverts. It is not a guard to route
around: update it to assert the new contract (a missing or corrupt cache
acquires) and add the counterpart for change 2 (a usable cache plus `--fetch`
still acquires). Say in the test name and comment what the contract now is.

Line budget, measured at `28e4d582c`: `worktree_runtime.tl` 369,
`worktree_runtime_test.tl` 453, `gitworktree.tl` 426 — all under the 500 cap
with room.

Pick 1 and 2 together; they are one contract. If implicit acquisition turns
out to be unsafe — a path that must stay offline reaching the network — that
is a blocker worth reporting rather than working around.
