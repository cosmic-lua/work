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
