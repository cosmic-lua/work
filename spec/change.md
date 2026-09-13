Ready when: `ls cosmic/htmx.tl cosmic/http/static.tl 2>/dev/null | wc -l` prints `2`.

That is the htmx and static children both merged; today the command
prints 0.

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
   `docs/guides/htmx.md` is a `.md` under `--make lint`'s walk:
   `--make lint`'s `doc-citation` rule refuses an inline `` `path:line`
   `` citation in committed markdown (docs/guides/lint.md) — quote a
   fixture file as a FENCED citation (a `-- path:line` comment as the
   code block's first line) rather than a bare inline pin.
3. `docs/guides/index.md`: append the guide's line.
4. Gate: `bin/cosmic --make ci` ends `ci: PASS`, which now builds and
   drives the fixture.
