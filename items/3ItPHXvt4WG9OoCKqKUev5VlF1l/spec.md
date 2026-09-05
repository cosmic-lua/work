## Evidence

Machine-detecting a CONTRADICTION between two documents needs semantics the tree does
not have. What is mechanical is collecting every place the shipped documentation
speaks about one symbol and printing them together, so a person or an agent reading
`--docs cosmic.fs.read` sees the guide sentence, the recipe and the sibling module's
aside beside the function's own doc — and a disagreement costs one screen to notice
instead of a search across the guides.

Today `--docs <symbol>` renders the symbol's own doc comment and nothing else, and the
guides that mention it are found only by knowing to look:

```
$ grep -c "fs.read\b" docs/guides/*.md | grep -v ":0"
docs/guides/checking.md:2
docs/guides/recipes.md:2
docs/guides/testing.md:1
```

Three guides teach `fs.read` and `--docs cosmic.fs.read` names none of them. The
corpus is already in the binary — `docs/guides/**` ships at `/zip/docs/guides` and
`cosmic.doc.embedded_index()` carries every module's, function's and example's prose —
so no new payload is needed.

FTS5 is the right engine for this and the default tokenizer is not: `unicode61` splits
`cosmic.fs.read` into three tokens, so a match on `read` is everything. `unicode61`
takes a `tokenchars` option, and `tokenchars '._:'` keeps `fs.read`, `cosmic.fs.read`
and `db:query` whole, so a MATCH on the symbol's spellings finds exactly the sections
that name it, ranked, with `snippet()` for the line. Measured 2026-09-05 with
`o/bin/cosmic` (FTS5 present):

```
$ o/bin/cosmic tok.lua      # CREATE VIRTUAL TABLE m USING fts5(text, tokenize = "unicode61 tokenchars '_.:'")
tokenchars:	true
  terms:	and busy_timeout call cosmic.fs.read db:query then
match cosmic.fs.read:	1
```

The corpus is the size the docs-search item measured (5,954 index rows plus 13
guides), so the build is in the same tens-of-milliseconds band and is paid only on
a symbol lookup.

## Change

1. `cosmic/doc/mentions.tl` (new shard; `query.tl` is at 483 of 500 lines):
   `mentions(symbol: string): {Mention}` where `Mention` is `{source: string, heading:
   string, line: integer, text: string}` and `source` is `guide.<topic>`,
   `<module>` (its module doc), `<module>.<function>` or `<module>.Example_<name>`.
   - Corpus: every `## ` section of every `/zip/docs/guides/*.md` (heading, body,
     fences INCLUDED — a recipe mentioning the symbol in code is a mention), plus every
     `module_doc`, function `description` and example `body` in the index. Built once
     per process into an in-memory FTS5 table `(source UNINDEXED, heading UNINDEXED,
     line UNINDEXED, text, tokenize = "unicode61 tokenchars '._:'")`.
   - Spellings queried, ORed and quoted: the full name (`cosmic.fs.read`), the
     short name with its last module segment (`fs.read`), and the method spelling
     when the symbol is a record method (`Database:query` → `db:query` is not
     derivable, so the record-method form matches `:query` by prefix token — document
     the limit).
   - The symbol's OWN entry is excluded from the result (its doc is already printed).
   - Without FTS5 (`pragma_module_list` probe, as `cosmic/sqlite/zipfile_test.tl`
     asks): a plain `string.find` over the same corpus with the same spellings, no
     ranking — the feature is never absent, only unranked.
2. `cosmic/doc/show.tl`'s symbol rendering appends a section when the list is not
   empty:

   ```
   Mentioned in:
     guide.recipes § CLI script skeleton                     line 25   local data, read_err = fs.read(path as string)
     guide.recipes § index files into sqlite (walk + hash + sqlite)  line 76   local data = fs.read(path)
     guide.checking § ...                                    line 164  local text = fs.read("/etc/hostname") or ""
   ```

   one line per mention, sources sorted guide-first then modules, at most 12 (a
   `... and N more` tail), `snippet()`'s 12-token window as the text.
3. `cosmic/doc/mentions_test.tl`: `cosmic.fs.read` lists `guide.recipes` and
   `guide.checking`; a symbol nobody else names lists nothing and renders no section;
   the fallback path (force it by building the table over a connection where the
   probe says absent — a test hook `mentions._force_plain = true`) returns the same
   set unranked; a fenced-code mention counts.
4. `docs/guides/docs.md` shows the section in its `--docs` example.

## Non-goals

Judging agreement — the view lists, a reader judges. Tree prose the binary does not
ship (AGENTS.md, `docs/*.md` outside guides, board specs): a tree-side report over
those is a `_tool/` item if the shipped view proves useful. Cross-references INTO the
`cosmo.*` layer.
