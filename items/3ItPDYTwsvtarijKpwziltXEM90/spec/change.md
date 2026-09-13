1. `_build/prose_dupes.tl` (new, the shape of `_build/dupes.tl`: a `scan(root):
   {string}` returning one message per group, path-sorted, and a `TREES` list):
   - **Units.** In a `.tl` file, one unit is a maximal run of `---` lines (a doc
     comment); `--` comments are not units (they are implementation notes, and
     `_build/dupes.tl` already covers bodies). In a `.md` file, one unit is a paragraph:
     lines between blank lines or headings, fenced blocks skipped whole, the same fence
     tracking `_build/doc_paths_test.tl`'s `spans_of` does.
   - **Normalization.** Lowercase; every run of non-alphanumerics becomes one space;
     a `@param`/`@return` tag line contributes its description only, never the tag or
     the name (so two functions with the same parameter set do not match on tags).
   - **Floor.** 12 normalized tokens, measured above: the groups under it are
     one-line summaries (`Close the handle`) that are legitimately shared.
   - **Rules, the whole allowlist.** A unit is skipped when (a) its first line is
     `reads:`/`ref:` — the declared-input header convention `_build/*_test.tl` and
     `_tool/discover_test.tl` carry; (b) the file is under a `testdata/` directory.
     Nothing else: a legitimate second copy is fixed in the prose, never excused here.
   - **Trees.** The same `TREES` as `_build/dupes.tl` plus `docs`, `skills`, `sys`,
     `README.md` and `AGENTS.md` — the file set comes from the tree, and `CLAUDE.md`
     is never read (it is the symlink; scanning it doubles every AGENTS.md paragraph).
   - **Message.** `<site>  <site>: identical prose — keep one, point the other at it`,
     the first 60 normalized characters quoted, so the reader can find it.
2. `_build/prose_dupes_test.tl` (`--- reads:` the trees above, the way
   `_build/dupes_test.tl` declares its inputs): fixture roots under `TEST_TMPDIR` pin
   each judgment — two identical doc blocks fail naming both sites; a markdown paragraph
   duplicated across two files fails; a sub-floor block passes; a `reads:` header
   shared by two tests passes; a fenced block repeated in two guides passes (fences are
   code, gated by `_build/snippets_test.tl`); a tag-only difference does not separate
   two otherwise identical blocks — and `test_the_tree_holds_no_duplicates` asserts
   `scan(".")` is empty.
3. Clean the 18 real groups above by kind, in the same PR, so the gate lands at zero:
   kind 1 cuts the local function's copy; kind 2 moves the paragraph to the owning
   module and leaves a one-sentence pointer; kind 3 keeps the guide's copy. Every
   rewrite is an edit to comments and markdown only — no identifier, string literal or
   code moves (the docs-style skill's audit rule).
4. `docs/guides/lint.md` gets no section: this is a `_build/` ratchet the test stage
   runs, not a `--check lint` rule, exactly like `_build/dupes.tl`.
