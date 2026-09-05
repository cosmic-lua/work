## Evidence

`show` and `next` spawn one git process per claimed item on top of their
fixed cost. `_work/gitview.tl:36` `claim_ages` calls
`publish.touched_at(s, i.id)` for every open item with a `claim` or
`reviewer`; `_work/publish.tl:176` `touched_at` calls
`refs.committer_date_unix`, which is one `git for-each-ref
--format=%(committerdate:unix) <ref>` process (`_work/refs.tl:68`). The
reviewer of cosmic-lua/work#18 measured it on the live board on 2026-09-05
with `strace -f -e trace=execve`: five items in `doing` added five
`for-each-ref` processes to a bare `show` (11 where the fixed cost is 6),
which is why the Evidence of «cwi5_ntHB», measured with nothing claimed,
counted 6. At DOING_LIMIT (10) that is ten extra processes, ~250 ms, on the
two verbs every session runs first.

The snapshot already runs `for-each-ref` over every item ref
(`_work/refs.tl:40`, `--format=%(refname) %(objectname)`). `for-each-ref`
can emit `%(committerdate:unix)` in the same pass, so the touched time of
every ref is available for free where the load already is.

Separately, `gitview.tl:59` `ci_states` makes one `gh.head_checks` call per
open review-stage item with a PR — network reads, not processes; noted
here, not changed here.

## Change

The snapshot carries each ref's commit time; `touched_at` reads it instead
of spawning.

1. `_work/refs.tl` `for_each_ref`: the format becomes
   `%(refname) %(objectname) %(committerdate:unix)`, and the parsed row
   gains `touched: integer`. Every caller that splits the line by hand is
   found with `grep -n "for_each_ref\|objectname" _work/*.tl` and updated to
   the parsed field; none keeps parsing the string itself.
2. `_work/store.tl` (or the read half after the split, if that has landed
   — check `ls _work/storewrite.tl`): `list()` records `s.touched_at[id]`
   next to `leased_ref`/`leased_sha`.
3. `_work/publish.tl` `touched_at`: return `s.touched_at[id]` when the
   snapshot holds it; the per-ref `committer_date_unix` stays only as the
   fallback for an id the snapshot did not carry (a fresh store that never
   listed), and says so in its doc comment.
4. Tests: `_work/refs_test.tl` (or wherever `for_each_ref` is tested)
   asserts the third field parses for a real ref; a `_work/gitview_test.tl`
   case builds a fixture with three claimed items and asserts `claim_ages`
   spawns zero `for_each_ref`/`committer_date_unix` calls beyond the one
   snapshot (module-table counting stub, the pattern #18 introduced), and
   that the ages equal the fixture commits' times.

## Non-goals

`ci_states`' GitHub reads (their own item if the daily perf lane shows
them dominating `show`); the fixed-cost snapshot work («cwi5_ntHB», the
batch-merge item); changing any output.
