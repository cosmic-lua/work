# docs/guides/htmx.md: the shipped htmx guide (cosmic --docs guide.htmx) with a runnable todo app — templates, router, forms, SSE, the htmx asset as a project pin

## Goal

The document a builder (human or the G1 eval agent) reads to go from
`cosmic --docs guide.htmx` to a working htmx app in one sitting:
layout + fragment templates in `cosmic.template`, a router, a form
POST that returns a fragment, an out-of-band counter, an SSE stream,
the static handler serving `htmx.min.js` from inside the artifact —
and every code block runs, because the app it teaches is a fixture the
gate builds and drives.

## Evidence

Ready when: `ls cosmic/htmx.tl cosmic/http/static.tl 2>/dev/null | wc -l` prints `2`.

That is the htmx and static children both merged; today the command
prints 0.

Guides ship in the binary and are discovered by position:
`cosmic/doc/mentions.tl:71-84` `guide_files()` lists every `*.md`
under `/zip/docs/guides` except `index.md`, and `docs/guides/index.md:55`
onward is the reader's list a new guide is appended to. The example-
project doctrine for guides is `_build/doc_paths_test.tl:71` ("the
guides' example project: the reader's tree, not this one").

The asset question, settled here rather than in `cosmic.http`: the
artifact "carries its modules and `embed/**`" (`docs/guides/make.md:134`),
and a `*_pin.tl` lands its bytes under `o/3p/<name>/...`
(`docs/guides/make.md:227-229`), which is NOT embedded. So a project
that wants `htmx.min.js` inside its binary has, today, two shapes: a
pin plus a `*_gen.tl` that copies `o/3p/htmx/htmx.min.js` into
`embed/`, or committing the minified file under `embed/`. The guide
shows the pin+generator shape (the pin is the sha-verified one and
never puts a vendored blob in the tree); whether `--make` should grow
"a pin whose payload embeds" is a separate research item this guide's
PR files if the generator shape reads as a workaround.

## Change

1. `_make/testdata/htmx/` — a fixture project, hello-world-sized per
   AGENTS.md ("one per behaviour"): `cmd/todo/main.tl` (listen on port
   0, print `READY <port>`, serve), `todo/page.tmpl` + `todo/item.tmpl`
   (`{{mode html}}`, the layout as a function of the fragment),
   `embed/htmx.min.js` produced by `embed/htmx_gen.tl` from
   `3p/htmx/htmx_pin.tl` (pin the current htmx release; `sha256` from
   the download, pasted in the PR), `todo/store.tl` (an in-memory list),
   routes: `GET /` (page), `POST /todos` (fragment + `oob` count), `DELETE
   /todos/:id` (empty 200), `GET /events` (SSE tick). Enrol it in
   `_make/fixtures_test.tl` the way `hello`/`pkg`/`multi` are
   (`_make/fixtures_test.tl:126` `fixture("hello", {hello = "hello from
   hello"})` is the enrolment shape; re-run `grep -n '^fixture(' ` at
   pull),
   with a drive step: spawn the built binary, read `READY`, `fetch` `/`
   (asserts the page contains the item form), `POST /todos` with
   `HX-Request: true` (asserts the body is a fragment, not a page, and
   contains `hx-swap-oob`), `DELETE /todos/1` (200).
2. `docs/guides/htmx.md` — sections, each quoting the fixture's file
   verbatim (the doc-symbols ratchet `_build/doc_symbols_test.tl` checks
   names it mentions exist): why htmx fits cosmic (server renders,
   typed templates, one binary); the layout-as-function pattern with
   `htmx.reply`; the form round-trip; OOB; SSE with `res:event`; the
   static handler and the pin+generator for the asset; sessions as a
   server-side table keyed by `cosmic.rand` and a CSRF token as a hidden
   field checked in the POST handler (the pattern, six lines); running
   it (`cosmic --make build && ./o/bin/todo`); the header reference —
   one table mapping each `cosmic.htmx` function to its `HX-*` header.
3. `docs/guides/index.md`: append the guide's line.
4. Gate: `bin/cosmic --make ci` ends `ci: PASS`, which now builds and
   drives the fixture.

## Non-goals

- No change to `cosmic.http` or `cosmic.htmx` — a gap found while
  writing is a child item.
- Not a `--make` feature: if the pin+generator shape is judged a
  workaround, file the research item; do not build "embedding pins"
  here.
- No auth, no database: the store is a table. A SQLite variant is a
  recipe line, not a section.

## Access

- cosmic-lua/cosmic: read+write.
