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
data change in the product repo.

Depends on the sibling item («oJ31_ppvR», the manifest + reader) landing
first — this item is the reader's first real caller.

## Change

`_work/gitworktree.tl`'s `bootstrap()`: once the manifest reader from
«oJ31_ppvR» is available, look up the worktree's own manifest first; if
one exists, run its declared bootstrap command(s) (streamed exactly as
today, captured/summarized per the already-landed quiet-mode item
`YLxi_6fmt`) and return its own description for the verdict line. Fall
back to today's `bin/cosmic`/`third_party/lua` file-presence heuristics
only when no manifest is found — so a repo that hasn't adopted a
manifest yet keeps working exactly as it does today; this is additive,
not a breaking change for `cosmic-lua/cosmic` or `cosmic-lua/cosmopolitan`
until each gets its own manifest (a follow-on, not this item).

`default_base`: same shape — a manifest's declared default base branch
wins when present; the `repo:find("cosmopolitan", ...)` string match
stays as the no-manifest fallback.

Tests: a fixture tree carrying a manifest with a custom bootstrap
command and base branch, asserting both are honored; a fixture tree
with no manifest, asserting today's exact behavior is unchanged
(regression guard on the fallback path).

## Non-goals

Not writing an actual manifest for `cosmic-lua/cosmic` or
`cosmic-lua/cosmopolitan` in this item — it lands the caller and proves
it against a fixture; adopting a manifest in a real product repo is
each repo's own follow-on once this and the sibling brief-template item
are both in place. Not changing what `bootstrap()`'s verdict line looks
like for the no-manifest fallback path.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
