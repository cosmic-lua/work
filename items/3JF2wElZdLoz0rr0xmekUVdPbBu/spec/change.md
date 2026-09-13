1. `_types/gentype_parse.tl`: change the `@field` match at line 296
   from `([^%s]+)%s*(.*)$` (type, then description) to `(.+)$` (the
   whole rest, matching `@param`'s pattern at line 276), then call the
   existing `split_type_desc` on it — the same function `@param` calls
   at line 284 — to get `ftype`/`fdesc` correctly. The `if fname then`
   block's existing `?`-stripping logic and `table.insert` stay as they
   are, just reading from the new `ftype`/`fdesc` locals instead of the
   match's direct captures. This is a ~1-line net addition (a
   `local ftype, fdesc = split_type_desc(frest)` call); confirm your
   actual diff keeps `_types/gentype_parse.tl` at or under 500 lines
   when done (`wc -l` it after editing).
2. New file `_types/gentype_field_type_test.tl`, sized and shaped like
   `_types/gentype_return_test.tl` (check that file's header/require
   pattern and copy it — same module under test, same runner-mode test
   convention per D29). One case: a `@field` line whose type is
   `table<string, string|string[]>` (the exact upstream shape) parses
   to that full type string, not the truncated `table<string,`, and its
   description (when the annotation carries trailing prose after the
   type, as the real one does) is not corrupted into the type. Use
   `gentype.parse_module`/`generate_dtl` the way `gentype_test.tl:319`'s
   `test_data_class_and_type_export` does, asserting on the generated
   `.d.tl` text (e.g. `dtl:match("headers: table<string, string | string%[%]>")`
   or whatever the actual generated Teal spelling is — run it once to
   see the real output rather than guessing the exact rendering).
3. Rebuild «HPFM_HEPg»'s own diff against this fix to confirm it's
   actually the unblocking fix: from a fresh worktree of THIS item
   (not «HPFM_HEPg»'s, which stays untouched until this lands), run
   `bin/cosmic --make build` and confirm `o/_types/types_gen/cosmo/http.d.tl`
   is generated with a correct (untruncated) `headers` field type. This
   confirmation is evidence for this item's own `## Change`, not a
   change to «HPFM_HEPg»'s files.
4. `bin/cosmic --make ci` ends `ci: PASS`.
