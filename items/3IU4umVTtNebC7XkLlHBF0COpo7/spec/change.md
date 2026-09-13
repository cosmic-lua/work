1. `_make/check.tl` `check_files`: for each file, `seam.augment(
   f.path)`, then `teal.check(aug.source, {include_dirs =
   include_dirs, chunk_name = f.path})`. A read failure counts as a
   failed file with its error on stderr, matching the other two call
   sites' shape.
2. The regression the string-level unit tests structurally cannot
   catch: a fixture project carrying a runner-mode `*_test.tl`,
   checked from a tree with NO prior build, so a call site that never
   reaches the seam fails a gate instead of waiting for a reviewer.
   `_make/testdata/**` is where such fixtures live and
   `_make/fixtures_test.tl` checks, builds and runs them — add the
   runner-mode file to a fixture there (or a new one) and assert
   `--make check` passes.
3. Correct 3IOCdHTM's inventory claim where it is still load-bearing:
   `_tool/seam.tl`'s header names the callers, and after this there
   are three.
