One commit, reproducible from `git show 9ff72e9b` restricted to the
split's files (cherry-picking the relevant hunks is fine; entry text
byte-identical, never retyped):

1. Create `3p/tl/tl_patch/ast_cache.tl` (the five `ast-cache-*`
   entries) and `3p/tl/tl_patch/narrow.tl` (the fifteen `narrow-*`
   entries), each with its group header plus the shared
   mechanism-pointer and carried-not-forked paragraphs, exactly as
   `9ff72e9b` wrote them. Delete `3p/tl/tl_patch.tl` in the same
   commit.
2. Apply the eleven prose path renames from `9ff72e9b` (same hunks),
   plus `_make/patch_test.tl`'s header sentence.
3. `bin/cosmic --make coverage --baseline` if the coverage gate asks
   (two new tree files, one deleted); any other ratchet, run exactly
   the regen command its failure message prints and commit the
   result.
