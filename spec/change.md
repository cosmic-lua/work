Delete the `as` cast and its `-- cast: function shape` marker at each
of these ten sites, and nothing else.

**Re-verified end to end 2026-08-23 at main `d01ea6ac`** in a detached
worktree: all ten deletions applied together, `bin/cosmic --make check`
ends `check: PASS (513 files)` and `bin/cosmic --make ci` ends
`ci: PASS (5 stages)` with the regenerated baseline. Nothing has drifted
since the wave-6 research at `aaf4af95` — the markers are at the same
line numbers, and `git grep -h -o -E -- '-- cast: [^(]*' -- '*.tl' | wc
-l` still prints 444.

```
_cli/require_hints.tl:237       _G.require = enhanced_require as function(string): any
cmd/cosmic/main.tl:467          local run_chunk = chunk as function(...: any): any ...
cosmic/coverage/init_test.tl:23 return chunk as function()
cosmic/fetch/init.tl:381        Fetch as (function(string, any): (any, any)),
cosmic/fetch/init.tl:382        stream as (function(string, any): (any, any)),
cosmic/fetch/init.tl:419        get = made.get as (function(string, Options): (Response | nil, Error)),
cosmic/fetch/init.tl:421        post = made.post as (…)
cosmic/fetch/init.tl:423        put = made.put as (…)
cosmic/fetch/init.tl:425        delete = made.delete as (…)
cosmic/fetch/init.tl:427        download = made.download as (…)
```

Re-locate by the marker string, not by number, if main has moved.
`git grep -n -- "-- cast: function shape" -- '*.tl'` prints 20 lines
today; the ten above are the ones this wave takes. Three shapes:

- `cmd/cosmic/main.tl:467` carries a varargs return, so the whole
  ` as function(...: any): any ...` suffix goes, leaving
  `local run_chunk = chunk`.
- `cosmic/fetch/init.tl:381-382` are ARGUMENTS to `fetch_extras.make`,
  each on its own line with a trailing marker: the line becomes
  `  Fetch,` and `  stream,`.
- `cosmic/fetch/init.tl:419-427` carry the marker as a STANDALONE
  comment on the line above each entry, so both lines collapse to one
  (`  get = made.get,` and its four siblings).

**Regenerate the cast floor in the same commit** —
`bin/cosmic --make run _build/casts.tl --baseline`. This is required,
not cosmetic: `_build/casts_test.tl` matches the counts EXACTLY, not as
a ceiling. Measured 2026-08-23, `--make ci` without the regen ends
`ci: FAIL (coverage)` on
`.coverage/_build/casts_test.tl` with `cosmic/fetch/init.tl: 8 casts
(baseline 15)`. The regenerated file's own summary line reads
`casts: wrote _build/casts_baseline.tl — 434 casts in 130 files`
(444 in 132 today), and its diff is exactly four rows — note that TWO
of them are row REMOVALS, because a file at zero is absent from the
floor rather than present with a 0:

```
-  ["_cli/require_hints.tl"] = 1,          (row deleted)
-  ["cosmic/coverage/init_test.tl"] = 1,   (row deleted)
-  ["cmd/cosmic/main.tl"] = 4,   +  ["cmd/cosmic/main.tl"] = 3,
-  ["cosmic/fetch/init.tl"] = 15, +  ["cosmic/fetch/init.tl"] = 8,
```

**In-flight overlap to expect.** PR #1328 (item `3I7Otbvg`, cast wave 4)
also regenerates `_build/casts_baseline.tl` and is in `check` as of
2026-08-23. If it merges first, main's totals are 443 in 132 files and
the two numbers in Acceptance below become 433 and 5, `_tool/testrun.tl`
reads 1 and `cosmic/string_test.tl` reads 3 — refresh them at pull per
the slice loop. A conflict in `_build/casts_baseline.tl` is resolved by
re-running the regen command on the merged tree, never by editing the
rows by hand.
