**`cosmic/fs/find.tl`** — reimplement `find`, in place, as a drain of
`find_iter`:

- Move the `FileIter` record and the `find_iter` function (currently
  `find.tl:155-303`) to before `find` (currently `find.tl:103-120`) —
  `find`'s new body calls `find_iter`, and Teal locals must be declared
  before use, so the definition order in the file has to flip. Leave
  `find_info` and `glob` where they are, after `find_iter`, unchanged.
- Rewrite `find`'s body to:
  ```
  local function find(dir: string, opts?: FindOptions): Found | nil, string
    local iter, ierr = find_iter(dir, opts)
    if not iter then
      return nil, ierr
    end
    local results: Found = {}
    for p in iter do
      table.insert(results, p)
    end
    local _, errs = iter()
    if opts and opts.sorted then
      table.sort(results)
    end
    results.errors = errs
    return results
  end
  ```
  The `for` loop is a full, unbroken drain — the release path
  `find_iter`'s own doc comment (`find.tl:175-176`) already documents —
  so no `<close>` attribute or explicit `iter:close()` is needed. Calling
  `iter()` once more after the loop reads the terminal `nil, errs` pair
  exactly the way `find_iter`'s own doc example does.
- Update `find`'s doc comment to say it drains `find_iter` (not
  `fs_walk.visit`) and drop the now-inaccurate `@param`/`@return`
  wording only if it names `visit`; the existing wording ("Slot 2 means
  the root failed; subtree failures ride on the result as
  `found.errors`") is still accurate and can stay.
- No other function in the file changes body. `fs_walk` stays imported
  (line 13) — `find_info` still calls `fs_walk.visit` at its current
  line — so the import is not removed.
- The reordering nets to no line-count growth: moving a block plus
  shrinking `find`'s body from 18 lines to about 15 keeps the file at
  its current 400 lines, unchanged from today and well under the
  500-line cap `--make lint` enforces.

**`_perf/bench/fs_bench.tl`** — add one scenario, `fs_find_tree`, placed
directly after `fs_files_tree` (after line 106 in the current file) so
the three file-collection scenarios (`fs_walk_tree`, `fs_files_tree`,
`fs_find_tree`) sit together:

```lua
{
  -- Exercises fs.find() itself (not find_iter directly): the scenario
  -- the fs_walk_tree vs fs_files_tree gap was never gated on.
  name = "fs_find_tree",
  fn = function(_: any): any
    local found = check.must(fs.find(tmpdir, {glob = "*.txt"}))
    return #found
  end,
  check = function(_: any, res: any): boolean, string
    if not (res is integer) then
      return false, "fs_find_tree: result is not an integer"
    end
    local count = res
    if count ~= DIRS * FILES_PER_DIR then
      return false, string.format("found %s *.txt files, want %d",
        tostring(count), DIRS * FILES_PER_DIR)
    end
    return true
  end,
},
```
Same shape as its two neighbors: reuses `tmpdir`/`DIRS`/`FILES_PER_DIR`
from `init_tree`, same glob, same expected count (`DIRS * FILES_PER_DIR`
= 200), `check.must` already imported (used by `fs_files_tree`).

**No test file needs to change.** Verified this refinement, in a
throwaway clone of this tree (`git clone /home/user/cosmic
/tmp/fs-find-refine`, discarded after) with the `find.tl` reorg above
applied: `o/bin/cosmic --make test cosmic/fs/walk_test.tl
cosmic/fs/find_close_test.tl cosmic/fs/glob_test.tl` — output `3 checks:
3 passed / 35 tests: 35 passed / test: PASS (3 files)`, unmodified
against the reimplementation. `o/bin/cosmic --check fmt|types|lint
cosmic/fs/find.tl` all reported PASS on the reorganized file, no cast or
line-length fallout.
