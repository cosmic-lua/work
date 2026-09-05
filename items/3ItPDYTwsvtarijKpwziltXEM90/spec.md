## Evidence

`_build/dupes.tl` fails the gate on two identical top-level function BODIES. Nothing
looks at prose: a doc-comment block or a markdown paragraph pasted into a second place
passes fmt, check, lint, coverage and the body gate, and then the two copies drift —
one gets corrected, the other keeps teaching the old shape.

Measured 2026-09-05 at c39fc2f with a 60-line scanner (below): every `---` doc-comment
block in the `.tl` files and every paragraph in the `.md` files, comments and fences
skipped, normalized to lowercase alphanumerics, blocks of 12+ tokens only. Result:

```
3843 blocks of 12+ tokens in 704 files; 55 exact-duplicate groups
```

Of the 55, 36 pair `CLAUDE.md` with `AGENTS.md` — `CLAUDE.md` is a symlink to it
(`ls -la CLAUDE.md`), so a scanner must read the model's file set, not walk the
directory. Of the remaining 19, one is the `--- reads: ...` declared-input header two test
files share by convention. The groups:

    _build/nil_returns.tl:169  _build/casts.tl:95
    _build/nil_returns.tl:44  _build/casts.tl:38
    _build/nil_returns.tl:40  _build/casts.tl:31
    _cli/build/batch.tl:29  _cli/build/work.tl:49
    _perf/bench/http_bench.tl:24  _perf/bench/download_bench.tl:41  _perf/bench/stream_bench.tl:47
    cosmic/teal.tl:231  cosmic/embed/init.tl:483
    cosmic/fetch/init_test.tl:10  cosmic/fetch/verbs_test.tl:22
    _fuzz/literal_fuzz_test.tl:18  _fuzz/json_fuzz_test.tl:18
    _fuzz/literal_fuzz_test.tl:97  _fuzz/json_fuzz_test.tl:39
    _eval/checks/contained-task.tl:16  _eval/checks/module-tests.tl:22  _eval/checks/json-cli.tl:19  _eval/checks/child-tcp.tl:57  _eval/checks/text-report.tl:29  _eval/checks/multi-module-build.tl:39  _eval/checks/sqlite-indexer.tl:11
    docs/design/make/verbs.md:74  docs/guides/make.md:46
    cosmic/fs/init.tl:30  cosmic/fs/init.tl:66
    cosmic/fs/find.tl:20  cosmic/fs/find.tl:395
    _perf/run.tl:355  _eval/stage.tl:317  _build/size.tl:280
    _make/build_test.tl:80  _make/build_incremental_test.tl:81  _make/clean_test.tl:80
    _perf/baseline.tl:92  _perf/peers/args.tl:38  _perf/run.tl:50  _eval/stage.tl:62  _eval/bundle.tl:48
    _tool/coverage/baseline_test.tl:27  _tool/coverage/baseline_corpus_guard_test.tl:24
    _make/seed_test.tl:16  _make/project_test.tl:20
    _tool/discover_test.tl:2  _build/nil_returns_test.tl:2   (the reads: convention — excluded by rule below)

Three kinds are in that list, and the fix differs per kind:

1. **A function's doc pasted onto the module record's field for it** —
   `cosmic/fs/find.tl:20` and `:395` ("Convert a glob pattern to a Lua pattern...",
   the `local function` and the `glob_to_pattern` record field), `cosmic/fs/init.tl:30`
   and `:66`. `--docs` renders both copies (function and method). Keep the record
   field's copy — that is the one `--docs cosmic.fs.glob` serves — and cut the local
   function's to its one-line summary.
2. **Sibling modules carrying one explanation each** — `_build/casts.tl` and
   `_build/nil_returns.tl` share three paragraphs (the trees the count covers, the
   committed floor, the rewrite command); the five `parse command line arguments`
   blocks; the `_eval/checks/*` entry contract. The explanation moves to the one
   module that owns the mechanism (`_build/ratchet.tl` for the floor paragraphs) and
   each sibling's comment becomes one sentence naming it.
3. **Guide prose copied from a design doc** — `docs/design/make/verbs.md:74` and
   `docs/guides/make.md:46`. The guide ships; the design doc is the record. The guide
   keeps the paragraph; the design doc points at the guide.

The scanner needs no SQLite: exact matching over normalized text is a hash table, the
same shape `_build/dupes.tl` uses. Near-duplicate detection (a paragraph re-worded) is
a different tool with a threshold to measure and is its own item; this gate is exact
and zero-tolerance so a tree joins its scope only when clean and stays clean at no
cost, which is the rule `_build/dupes.tl` set (its header quotes the two escapes that
motivated it).

The measurement script, so the puller reproduces the 19 in seconds
(`o/bin/cosmic prose_dupes_census.lua` from the repo root):

```lua
local fs = require("cosmic.fs")
local files = {}
local function walk(d) local h = fs.open_dir(d); if not h then return end
  while true do local n = h:read(); if not n then break end
    if n ~= "." and n ~= ".." and n ~= "o" and n ~= ".git" and n ~= ".claude" and n ~= "3p" and n ~= "testdata" then
      local p = d .. "/" .. n; if fs.is_dir(p) then walk(p) elseif n:match("%.tl$") or n:match("%.md$") then files[#files+1] = p end end end
  h:close() end
walk(".")
local groups = {}
local function add(path, line, text)
  local norm = text:lower():gsub("[^%w]+", " "):gsub("^ ", ""):gsub(" $", "")
  local ntok = 0 for _ in norm:gmatch("%S+") do ntok = ntok + 1 end
  if ntok < 12 then return end
  groups[norm] = groups[norm] or {}
  table.insert(groups[norm], path:sub(3) .. ":" .. line)
end
for _, path in ipairs(files) do
  local lines = {} for l in ((fs.read(path) or "") .. "\n"):gmatch("(.-)\n") do lines[#lines+1] = l end
  if path:match("%.tl$") then
    local block, start = {}, nil
    for i, l in ipairs(lines) do
      local c = l:match("^%s*%-%-%-%s?(.*)$")
      if c then if not start then start = i end; block[#block+1] = c
      elseif start then add(path, start, table.concat(block, " ")); block, start = {}, nil end
    end
  else
    local para, start, infence = {}, nil, false
    for i, l in ipairs(lines) do
      if l:match("^```") then infence = not infence end
      if infence or l:match("^```") or l:match("^%s*$") or l:match("^#") then
        if start then add(path, start, table.concat(para, " ")) end; para, start = {}, nil
      else if not start then start = i end; para[#para+1] = l end
    end
    if start then add(path, start, table.concat(para, " ")) end
  end
end
for norm, sites in pairs(groups) do if #sites > 1 then print(table.concat(sites, "  ")) end end
```

## Change

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

## Non-goals

Near-duplicate (re-worded) prose — a threshold to measure, filed separately. Comment
QUALITY (the docs-style audit) — this gate says only "these two are the same". Fenced
code in markdown — `_build/snippets_test.tl` owns fences. `--` implementation comments.
