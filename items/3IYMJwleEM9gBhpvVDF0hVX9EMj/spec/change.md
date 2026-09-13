In `cosmic/fs/types.tl` (300 lines — `wc -l cosmic/fs/types.tl`),
retype the `statfs_methods` table's 9 method functions (the block at
lines 213–241) so each one declares its `self` parameter as
`unix.Statfs` instead of `any`, and calls the binding method directly
on `self` instead of casting first. `grep -n "cast: userdata boundary"
cosmic/fs/types.tl` shows the 9 casts to remove sit at lines 215, 218,
221, 224, 227, 230, 233, 236, 239 — one per method, all inside
`statfs_methods`. For each of these 9 (`block_size_bytes`→`bsize`,
`fragment_size_bytes`→`frsize`, `total_blocks`→`blocks`,
`free_blocks`→`bfree`, `available_blocks`→`bavail`,
`total_files`→`files`, `free_files`→`ffree`, `id`→`fsid`,
`max_name_bytes`→`namelen`), change:

```
NAME = function(self: any): RET
  return (self as unix.Statfs):BINDING() -- cast: userdata boundary
end,
```

to:

```
NAME = function(self: unix.Statfs): RET
  return self:BINDING()
end,
```

Leave everything else in the file untouched: `statfs_methods`'s own
declared type stays `{string: any}` (a concretely-typed function value
still satisfies an `any`-valued table, and `extend_metatable`'s
signature — `extend_metatable(raw: any, extra: {string: any}):
boolean` — does not change); `raw_predicates`, `install_predicates`,
`wrap`, and `wrap_statfs` are untouched, including the 3 casts that are
NOT part of this change: `install_predicates`'s `raw as any` (line
263), `wrap`'s `raw as fs_types.Stat` (line 280), and `wrap_statfs`'s
`raw as fs_types.Statfs` (line 294). Those 3 are wrap-point casts —
part of the census's six-wrap-point floor in `docs/design/casts.md`'s
`### userdata boundary` section — and stay. Every edited line is a
1-for-1 replacement (the function-header line and its one-line body
each keep their line count), so the file stays 300 lines and none of
the surviving casts' line numbers move: `docs/design/casts.md`'s
fenced quote at `cosmic/fs/types.tl:280` needs no update.

After the edit:

- Run `bin/cosmic --make ci` — the 9 rewritten lines must type-check
  with no `as`, and the whole gate (fmt, check, example, lint,
  coverage) must stay green.
- Run `bin/cosmic --make run _build/casts.tl --baseline` and commit
  the result — `_build/casts_baseline.tl`'s row `["cosmic/fs/types.tl"]
  = 12,` (confirmed today: `grep -n 'fs/types.tl' _build/casts_baseline.tl`)
  must become `= 3,`.
- Run `bin/cosmic --make run _build/cast_sites.tl --reconcile` and
  commit the result — `docs/design/cast-sites.tsv` drops its 9 rows for
  `cosmic/fs/types.tl` at lines 215/218/221/224/227/230/233/236/239.
  `_build/cast_sites_test.tl` fails the build if this file and the
  baseline disagree, so both regenerations land in the same commit.

Add a runtime test proving the retyped methods still work against the
real binding: today nothing calls `fs.statfs`/`fs.statfs_fd` in any
test — `grep -rln 'statfs\b' cosmic --include=*_test.tl` finds only
`cosmic/fs/traps_test.tl` (a capability-name list that mentions the
string `statfs_fd`, never calls it) and `cosmic/fs/dir_test.tl` (an
unrelated match); no test exercises the wrapped `Statfs` methods this
change retypes. In `cosmic/fs/ops_test.tl` (348 lines — `wc -l
cosmic/fs/ops_test.tl`, well under the 500-line cap), add
`test_statfs_reports_plausible_values`: call `fs.statfs(".")`, assert
success, then assert on values from all 9 retyped methods without
hardcoding filesystem-specific numbers — e.g. `block_size_bytes() > 0`,
`total_blocks() > 0`, `free_blocks() <= total_blocks()`,
`total_files() >= 0`, `free_files() <= total_files()`,
`fragment_size_bytes() > 0`, `available_blocks() <= total_blocks()`,
`max_name_bytes() > 0`, and `id()`'s two returned values are both
integers.
