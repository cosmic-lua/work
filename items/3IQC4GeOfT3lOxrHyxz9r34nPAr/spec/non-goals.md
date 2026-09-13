- **No `.tl` file is touched.** This slice closes no cast and moves no
  count. `git diff --name-only` against `main` must name
  `docs/design/casts.md` and nothing else.
- **`docs/decisions/d28-shape-combinators.md` is not touched**, and
  neither is any other record under `docs/decisions/`. D28's context
  carries its own stale figures ("192 of the tree's 389 `as` casts",
  "61 sites"); a record states the decision as it was made, and
  amending one is the `decide` skill's business, never a side effect of
  a docs slice.
- **No generator.** The earlier filing offered deriving the tables from
  the tree the way `_build/casts_baseline.tl` is derived. Nine sites do
  not earn a generator, and this change removes the tables rather than
  producing them.
- **`_build/casts.tl`, `_build/casts_baseline.tl` and
  `_build/casts_test.tl` are untouched.** The cast ratchet is a
  separate mechanism and is working.
- **Never a ```teal fence.** `_build/snippets_test.tl` compiles and
  format-checks every `teal` fence at full strictness, and a quoted
  cast line is not a compilable module. Every fence this slice writes
  is ```text.
- **Do not delete the document** or fold it into another. D28 links to
  it, and the class taxonomy is what a future from-any site is read
  against.
- **Do not rename the file or its headings.** The `### Decoded-data
  shaping` heading in particular is what D28's sentence points a reader
  at.
