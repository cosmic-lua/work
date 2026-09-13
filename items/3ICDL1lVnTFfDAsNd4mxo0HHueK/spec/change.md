Make `parse` a pure function of `display` in `_tool/coverage/report.tl`,
so no chunk spelling can influence it. Measured now: `wc -l <
_tool/coverage/report.tl` is 444 (56 lines of headroom under the
500-line cap) and `wc -l < _tool/coverage/report_test.tl` is 174.

1. Add one private helper beside `normalize`:

   ```teal
   --- The file whose text is analyzed for a display path's executable
   --- lines. Hits are recorded at compiled line numbers, so the
   --- universe comes from the compiled artifact when there is one.
   local function parse_for(display: string): string
   ```

   It returns `"o/" .. display:gsub("%.tl$", ".lua")` when `display`
   ends in `.tl` and that file exists (`fs.is_file`), and `display`
   otherwise. This is the rule the zero-hit fallback at :394 already
   applies inline; the change is that it now governs every entry.

2. Drop `normalize`'s second return. Its signature becomes
   `function(src: string, cwd: string): string | nil`, every branch
   returns the display path alone (the `/zip` branch at :108, the `o/`
   branch at :129, the direct-source branch at :133), and the
   `ReportModule` record (:431) and the `M` table (:439) follow.

3. `merge_hits` (:214) drops its `parse` parameter and sets
   `parse = parse_for(display)` when it creates the entry. Its caller
   (:386) becomes `local display = normalize(src, cwd)` /
   `merge_hits(entries, display, lines)`.

4. The `src_files` zero-hit loop (:393-:400) uses `parse_for(s)` in
   place of its inline `compiled` expression.

5. Keep `FileEntry.parse` — `analyze` still reads it — but it is now
   derived from `display` at the one point an entry is created, never
   chosen by whichever chunk arrived first.

In `_tool/coverage/report_test.tl`:

6. Update the four `normalize` tests that bind a second return
   (`test_normalize_maps_compiled_artifact_to_source`,
   `test_normalize_maps_embedded_directory_modules`,
   `test_normalize_maps_lua_only_source_with_no_tl`,
   `test_normalize_accepts_existing_tl_script`) to assert the single
   display return. Their display assertions do not change.

7. Add `test_denominator_is_independent_of_chunk_spelling`, which pins
   the property directly rather than trying to control merge order.
   Under `TEST_TMPDIR`, write a source `mod.tl` containing a `local
   record R … end` plus a couple of executable statements, and a
   compiled `o/mod.lua` whose corresponding line is a plain `local R =
   {}` assignment — so the two files' executable-line sets differ by
   that line, exactly as the measurement above shows for real modules.
   Write two `.cov` directories holding the SAME hit table, one under
   the chunk key `"@/zip/mod.lua"` and one under `"@o/mod.lua"`. With
   the cwd set to that tree, call `report.compute` on each directory
   and assert the `mod.tl` row's `total` is equal in both. Restore the
   cwd before asserting, as `test_normalize_maps_lua_only_source_with_no_tl`
   does.
