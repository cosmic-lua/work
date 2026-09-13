In every `*_test.tl` under this batch's scope, delete each line
matching exactly `^test_[A-Za-z0-9_]*()$` — a bare call at column 1, no
arguments. Nothing else changes in those files, and no file outside the
scope is touched. `cosmic/fs/glob_test.tl` is excluded.

The edit is mechanical; do it with a throwaway script run from the repo
root, kept OUT of the tree (a `*.tl` inside it joins the build graph):

```
grep -rln '^test_[A-Za-z0-9_]*()$' --include='*_test.tl' cosmic/fs cosmic/child cosmic/format cosmic/flags cosmic/coverage cosmic/sandbox | grep -v 'cosmic/fs/glob_test.tl' | xargs sed -i -E '/^test_[A-Za-z0-9_]*\(\)$/d'
```

**Then repair the cast-sites ratchet, which the deletion always
breaks.** `_build/cast_sites_test.tl` fails because
`docs/design/cast-sites.tsv` names cast sites by line number and the
deletion shifts them. The regen the failure message prints
(`bin/cosmic --make run _build/cast_sites.tl --reconcile`) cannot fix
it alone: reconcile keys a site on `path\tline`, so a moved site reads
as newly discovered with no class to carry forward and the tool
refuses to write (item 3IcGmqWF). Measured against c9b0b31f, exactly
five rows shift, and the cast text at old and new line is
byte-identical in all five (verified by comparing
`git show origin/main:<file> | sed -n '<old>p'` against
`sed -n '<new>p' <file>` — all SAME):

| file | old | new |
| --- | --- | --- |
| `cosmic/fs/find_close_test.tl` | 86 | 85 |
| `cosmic/fs/find_close_test.tl` | 88 | 87 |
| `cosmic/sandbox/init_test.tl` | 50 | 48 |
| `cosmic/sandbox/init_test.tl` | 110 | 107 |
| `cosmic/sandbox/init_test.tl` | 119 | 116 |

(`cosmic/sandbox/init_test.tl:21` does not move.) Update ONLY those
line numbers, carrying each row's class string forward verbatim, then
re-run `--reconcile` and confirm it reproduces the file byte for byte
(`md5sum` unchanged across the run — it was `29404957d8083f730510a84d399e97ed`
at measurement). If the numbers have drifted, re-derive them the same
way; never invent or change a class, and never weaken the gate.
