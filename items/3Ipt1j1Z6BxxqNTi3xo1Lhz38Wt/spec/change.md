- New file `3p/tl/tl_patch/declining_searcher.tl` with two entries (the
  `tl.lua`/`tl.tl` pairing this directory already uses for a builtin-type
  fix, e.g. `narrow-assert-decl` / `narrow-assert-decl-tl-tl` in
  `3p/tl/tl_patch/narrow.tl`):

  ```teal
  return {
    ["declining-searcher-package-searchers"] = {
      file = "tl.lua",
      note = "a declining searcher returns a bare string, not a loader; the builtin type had no arm for it",
      find = [=====[      searchers: { (function(string): (function(? string, ? any): (any), any)) }
  ]=====],
      replace = [=====[      searchers: { (function(string): (function(? string, ? any): (any) | string, any)) }
  ]=====],
    },
    ["declining-searcher-package-searchers-tl-tl"] = {
      file = "tl.tl",
      note = "a declining searcher returns a bare string, not a loader; the builtin type had no arm for it (Teal ground truth)",
      find = [=====[      searchers: { (function(string): (function(? string, ? any): (any), any)) }
  ]=====],
      replace = [=====[      searchers: { (function(string): (function(? string, ? any): (any) | string, any)) }
  ]=====],
    },
  }
  ```

  Both `find` strings occur exactly once today in their respective
  files (verified above); `_make/patch.tl`'s apply enforces that on
  every fetch regardless.
- `.cosmic-coverage`: add
  `["3p/tl/tl_patch/declining_searcher.tl"] = {["covered"] = 0, ["total"] = 1},`
  alongside the other `3p/tl/tl_patch/*.tl` rows (alphabetically
  between `closure.tl` and `enum.tl`) — required, or the coverage
  stage refuses the new unbaselined source (verified above).
- Run `bin/cosmic --make fetch` so the new patch applies into
  `o/3p/tl/tl.lua` and `o/3p/tl/tl.tl` — required before any check or
  build observes it (`3p/tl/tl_patch/*.tl` entries apply on fetch, not
  on write).
- `cosmic/searcher_test.tl` is left COMPLETELY UNTOUCHED — the
  `-- cast:` comment and the cast at line 57-58 both stay exactly as
  they are. Gen1 still type-checks this file against the OLD pinned
  checker (no `| string` arm) even in this same PR that adds the
  patch, since the pin itself does not move here; removing the cast is
  `zs1K_cWnY`'s scope, gated on a release + pin bump.
- `bin/cosmic --make ci` ends `ci: PASS` — with the patch present,
  applied via fetch, and the cast still in `cosmic/searcher_test.tl`
  (verified above).
