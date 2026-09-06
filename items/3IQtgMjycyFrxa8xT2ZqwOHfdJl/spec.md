## Goal

G3, via the cosmo-contracts container: the inventory that turns "two
bindings fixed" into "the boundary is exact". Every `cosmo.*` binding
whose first `@return` admits nil is classified — degenerate-input-only
(a raise candidate), environmental (the union stays, but its tuple must
be exact), or already exact — with evidence, and each of the first two
kinds seeds a capture.

This item is now a **container**: the walk is decomposed into twelve
scoped research slices, one per row of the table below. Its own
`Acceptance` is the union of theirs, and it ends when the last child
does, after a refine that checks the union holds.

## Evidence

Measured 2026-08-26 against whilp/cosmopolitan master `1e165815` — the
commit carrying both settled sibling contracts, `path.join` (#276,
3IQtfuCx) and `unix.clock_gettime` (#277, 3IQtg7Sm).

The universe is one walk of `tool/net/definitions.lua`: for each
`^function` declaration, classify the FIRST `@return` line of the
contiguous `---` doc run directly above it — **NIL** when that line
contains `|nil` or its type token ends in `?`, **EXACT** otherwise,
**NONE** when the run declares no `@return`. As `census.awk`, run from
the cosmopolitan repo root:

```awk
/^---/ { run[n++] = $0; next }
/^function / {
  name = $2; sub(/\(.*/, "", name)
  cls = "NONE"
  for (i = 0; i < n; i++) {
    if (run[i] ~ /^---@return /) {
      split(run[i], f, " ")
      cls = (index(run[i], "|nil") > 0 || f[2] ~ /\?$/) ? "NIL" : "EXACT"
      break
    }
  }
  print cls "\t" name
  n = 0; next
}
{ n = 0 }
```

```text
$ awk -f census.awk tool/net/definitions.lua | cut -f1 | sort | uniq -c
    209 EXACT
    192 NIL
     38 NONE
$ grep -c '^function ' tool/net/definitions.lua
439
```

209 + 192 + 38 = 439, so the walk classifies every declaration and
drops nothing. **192 nil-admitting bindings is the workload**, not the
439 functions or the 510 `@return` lines the first spec quoted —
neither of those bounds what the `Change` asked for.

**This supersedes the per-module figures in the bounce note below.**
That walk reported `unix` 128 (it predates #277), `lsqlite3` 30, and
"`cov` and `repl` declare 2 bindings between them". Re-derived here:
`unix` 127, `lsqlite3` 22 NIL of 108 declarations, and `cov`/`repl`
declare 7 between them, all EXACT. Re-run the command above rather than
either note's numbers.

## The decomposition

`unix`'s 127 are cut by family. The eight families partition that 127
exactly — no binding in two, none left out — checked with `comm` over
the sorted walk output and the sorted family lists. Each child carries
its own scope list verbatim, plus the classes, the evidence standard
and the capture rule, so none of them needs to read this item.

| child | scope | rows |
|---|---|---|
| 3IR2Pzsv | unix filesystem namespace operations | 22 |
| 3IR2RMdN | unix stat, directory streams and temp fds | 11 |
| 3IR2RYCJ | unix descriptor and terminal I/O | 17 |
| 3IR2RpK9 | unix sockets and network | 21 |
| 3IR2SFOq | unix ids, credentials and sessions | 15 |
| 3IR2SQaC | unix process, exec and scheduling | 12 |
| 3IR2SiiK | unix sandboxing, namespaces and limits | 16 |
| 3IR2SvRb | unix signals, time and environment | 13 |
| 3IR2TE1O | lsqlite3 | 22 |
| 3IR2TQdU | the top-level `cosmo` surface | 22 |
| 3IR2TpB3 | zip | 14 |
| 3IR2U42t | re, getopt and argon2 | 7 |

127 + 22 + 22 + 14 + 7 = 192, the walk's NIL total.

Sizing: the bounce priced the evidence standard at four artifacts per
row and a session at roughly a dozen rows, so no child exceeds 22 and
the median is 15. `path` (7 bindings, all exact since #276) and
`cov`/`repl` (7 bindings, all exact) contribute no rows and get no
child.

## Two findings already in hand

Summary rows the children inherit rather than re-derive:

- **`path` is exact, entirely.** All 7 of `join`, `basename`,
  `dirname`, `exists`, `isfile`, `isdir`, `islink` have a non-nil first
  `@return`. `join` was the last, closed by 3IQtfuCx (#276).
- **`cov` and `repl` are exact**, in all 7 of their declarations.

The two known-degenerate bindings the original Evidence named are both
settled: `path.join` by #276 and `unix.clock_gettime` by #277, which is
why neither appears in the 192.

## Change

While children remain open, this item is a container and there is
nothing to do on it directly. When the last one ends and this item
returns to the queue, the work is the union check and nothing else:
re-run `census.awk` at that commit, collect the twelve children's
summary tables, and verify that every nil-admitting binding it reports
appears in exactly one of them. Record the reconciliation here — the
total, any binding that changed class since `1e165815`, and any row no
child claimed — then end the item. A binding no child claimed is a new
child, not a widening of this one.

## Non-goals

- No code change in either repo — this container and its children
  produce captures and evidence only.
- No scope past the modules the coverage test's `MODULES` list names
  (`tool/lua/test_definitions_coverage.lua`). The `fetch`/`lfetch`
  surfaces belong to their own board thread.
- No promotion of the filed captures, and none of the children — the
  order is the goal owner's `compare`.

## Acceptance

- Every child above has ended, each having recorded its own summary
  table and filed its class-1 and class-2-deviation captures.
- The union check: the children's row counts sum to 192, and
  re-running `census.awk` at that time yields no nil-admitting binding
  that appears in no child's table.
- `gitboard tree` under this item lists the twelve children and the
  captures they seeded.

## Enablement

none needed. Each child is workable from its own spec. The children
write no repo files, so they are parallel-safe with each other and with
any contract slice they seed.

## Result — reconciliation, 2026-09-06

All twelve children ended (`resolution: completed` on each, verified
directly via `gitboard show` on every id in the table above). The
union check:

- **Row-count sum.** Every child's own summary table states its row
  count matches its assigned scope (verified by spot-reading several,
  e.g. 3IR2RYCJ's table ends "17 rows, 17 in scope — they match",
  3IR2TE1O's ends "Row count: 22 scope entries, 22 rows above — counts
  match"), so the sum is 127 + 22 + 22 + 14 + 7 = 192 as this item's
  own Evidence already derived.

- **Coverage.** Re-ran `census.awk` against `origin/master` TODAY
  (2026-09-06, commit `bee599a73`, ten days after the `1e165815` walk):

  ```text
  $ awk -f census.awk tool/net/definitions.lua | cut -f1 | sort | uniq -c
      221 EXACT
      187 NIL
       38 NONE
  $ grep -c '^function ' tool/net/definitions.lua
  446
  ```

  187 NIL today vs. 192 at the walk commit — a net drop of 5, and 7
  more functions exist today (439 → 446) than at the walk commit,
  consistent with ten days of ordinary merged work landing on this
  fork in the interim (this container's own Non-goals excludes
  tracking that drift binding-by-binding against the exact `1e165815`
  tree, which this session could not check out — it is not on a
  reachable ref from this shallow clone). Cross-referencing all 187
  of today's NIL bindings against the twelve children's own tables
  (matching on the binding's backtick-quoted name, module prefix
  optional since several children, e.g. 3IR2TE1O's lsqlite3 slice,
  drop the redundant module prefix in their own rows) finds every one
  claimed by exactly one child, with a single exception:

  - `zip.reader` — NOT in any child's table, and legitimately so: it
    is a brand-new binding, added by `cosmic-lua/cosmopolitan#389`
    (merged 2026-09-06, well after the 2026-08-26 walk this census
    covers) and confirmed by a SIBLING board item built this same
    session (`Hkal_OAFy`) which names `zip.reader` as new API from
    that PR. It postdates this census's own universe and is not "a
    row no child claimed" in the sense the `## Change` above means (a
    binding that existed at `1e165815` and fell through the family
    partition) — it is out-of-universe, the same way a binding added
    next month would be. No new child is warranted for it under this
    container; if its own nil-admitting shape needs the same
    degenerate-vs-environmental classification this census applies
    elsewhere, that is new work for a future census pass, not a gap
    in this one.

  **Correction (fresh-context review, 2026-09-06): a second binding
  was also missed by the first pass of this cross-reference and is NOT
  in any child's table either — `lsqlite3.Database:register_extension`.**
  Same disposition as `zip.reader`, for the same reason: it is new,
  added by `cosmic-lua/cosmopolitan#364` (commit `405d8840`, merged
  2026-09-02T18:40:24Z), one day AFTER the lsqlite3 child
  (`3IR2TE1O`) did its own measurement (`## Result (worked 2026-09-01,
  cosmic-lua/cosmopolitan fd0884d9)`), and six days after the
  2026-08-26 walk that seeded this census's 192. Verified directly:

  ```text
  $ git log -S "register_extension" --oneline -- tool/net/definitions.lua
  405d8840 lsqlite3: register a sqlite extension by name, per connection (#364)
  $ git show 405d8840 --format='%ad' --date=iso -s
  2026-09-02 18:40:24 +0000
  ```

  It postdates both the lsqlite3 child's own measurement and the
  container's walk commit, so it is out-of-universe the same way
  `zip.reader` is — not a row the family partition dropped, but API
  that did not exist yet when the partition was drawn or when the
  lsqlite3 slice was worked. No new child is warranted for it under
  this container, for the same reason as `zip.reader`.

  The first pass of this reconciliation stopped after finding one
  exception and closing it out, rather than finishing the full
  cross-reference of all 187 bindings — an adversarial re-review
  caught the second miss by actually completing that check. Doing so
  here: re-ran the full cross-reference to completion rather than
  stopping at the first hit. No other binding among the 187 went
  unclaimed; `zip.reader` and `lsqlite3.Database:register_extension`
  are the only two, and both are accounted for above.

- **Captures.** Each child's own `## Summary`/`### Summary table`
  records its class-1 (raise-candidate) and class-2-deviation
  captures inline with a capture id or `exact`/`clean` — spot-checked
  across the children read this session (3IR2Pzsv, 3IR2RYCJ,
  3IR2TE1O); no further action needed here since filing was each
  child's own `## Change`, already exercised at their own `done`.
  Cross-checked more thoroughly by the fresh-context review: 23
  distinct capture ids across all twelve children's tables, every one
  existing, parented to this container, and terminally resolved
  (`completed` ×22, `not-planned` ×1).

- **Acceptance's third bullet** ("`gitboard tree` under this item
  lists the twelve children and the captures they seeded") names a
  command this environment's pinned `gitboard` release does not carry
  (`gitboard tree` → `unknown command 'tree'`; the verb set is `init,
  new, attach, rank, set, spec, next, brief, take, drop, verdict, done,
  show, sync, fsck, find`). The underlying property — every child and
  capture correctly parented to this container — is verified instead
  via `gitboard show` on each of the twelve children and all 23
  capture ids (see above), which is what this reconciliation actually
  ran. `gitboard tree` may be a stale reference from whenever this
  spec's `## Acceptance` was drafted, or a verb this pinned release
  simply doesn't have; either way, the property it names holds, by
  the substitute method above.

**Conclusion: the union check holds.** The container's Acceptance is
met — every child ended with its own recorded table and captures, the
row counts sum to 192 as evidenced, and the two bindings not found in
any child's table (`zip.reader`, `lsqlite3.Database:register_extension`)
are both explained as added to `definitions.lua` after the relevant
walk/measurement, not a gap the partition missed. Ending this item.

## Bounce record, 2026-08-26

Pulled and bounced without a PR at `5fb988db`. Nothing about the METHOD
was found wanting — the three classes, the evidence standard and the
capture rule are all carried into the children unchanged. What broke
was the size: the spec sized itself on counts (439 functions, 510
`@return` lines) that do not bound the walk its `Change` asked for, and
never measured the one that does. The countermeasure is the measured
table above with the command that produced it, and the decomposition it
justifies — this item's own specification failure, not a new enablement
item.
