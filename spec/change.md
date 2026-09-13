Every site in the tree tagged with one of the four `narrowing-gap`-family reason
strings, measured 2026-08-19 (`git grep -n -- "-- cast: pcall result\|-- cast: or
fallback does not narrow\|-- cast: tuple element\|-- cast: record union after guard"
-- "*.tl"`, 22 lines across 12 files):

```
_build/dupes.tl:135, 143                          (tuple element)
_cli/build/init_test.tl:72, 144, 169              (or fallback does not narrow)
_eval/score_test.tl:66                            (pcall result)
_perf/bench/re_bench.tl:73                        (record union after guard)
cosmic/check.tl:268                               (record union after guard)
cosmic/fs/walk.tl:88                              (record union after guard)
cosmic/literal_test.tl:138, 162, 172              (pcall result)
cosmic/quicksand/box/run.tl:211                   (record union after guard)
cosmic/quicksand/proxy.tl:141                     (record union after guard)
cosmic/quicksand/proxy/rules_test.tl:57           (tuple element)
cosmic/re.tl:285, 316                             (tuple element)
cosmic/time.tl:132, 136, 138, 162, 166, 168       (tuple element)
```

For each site: read the guard immediately above the cast, and try removing the `as`
cast (and its trailing/leading `-- cast:` comment) while keeping the guard as-is or
restructuring it into the corrected narrowing shape documented in
`cosmic/teal_narrowing_test.tl` and AGENTS.md's "Narrowing nil unions" section
(`if not (x is T) then return/error(...) end` narrows on `return`, not on `error`;
`assert(x)` narrows as an expression; `x and x.field` narrows). Run `bin/cosmic
--check types <file>` after each edit.

- If the file now checks clean without the cast, the site is `removable-now`: keep the
  deletion, and delete the site's line from `_build/casts_baseline.tl` count for that
  file by regenerating (see Acceptance).
- If the checker still refuses without the cast, the site is a genuine narrowing gap:
  revert the file to its original cast + comment, unchanged. Do not weaken the guard
  or restructure the surrounding code to force a false positive — a site that still
  needs the cast stays exactly as it is today.

Do not touch any site outside the 22 listed above, even one carrying a similar reason
string discovered while editing a file in the list (e.g. a second `tuple element` site
in a file already on the list IS in scope only if it appears in the line list above;
one that turns up elsewhere is out of scope — file it as a new capture instead).
