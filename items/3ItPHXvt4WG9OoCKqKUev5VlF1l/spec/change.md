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
