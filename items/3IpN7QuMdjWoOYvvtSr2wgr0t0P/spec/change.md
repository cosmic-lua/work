`docs/guides/gotchas.md`: one entry, "Records are nominal": two
declarations with the same fields are unrelated types; a module that
returns a record value declares the record once and exports it through
its module record (`type Rows = Rows`), importers alias it (`local
type Rows = mod.Rows`), never re-declare; `local x: R =
setmetatable({}, mt)` types the seed by the annotation, no cast. Cite
`cosmic/sqlite/bind.tl` as the worked example. `docs/design/casts.md`,
the incremental-record class: add the sentence "when the cast bridges
two same-shaped declarations, the fix is the alias, not the literal".

`_build/docs_test.tl` gates the guide's paths; no new test.
