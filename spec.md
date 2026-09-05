## Evidence

`cosmic.doc.guide(topic)` serves markdown from a fixed embedded directory:
`cosmic/doc/query.tl:12` `GUIDES_DIR = "/zip/docs/guides"`, filled for the
cosmic binary by `cmd/cosmic/embed_gen.tl:72` ("docs/guides"). A project
built by `cosmic --make` ships its own payload from `embed/**` at the zip
root, so `embed/docs/guides/*.md` would land at exactly that path — and
`cosmic/**` is the strip floor, so `cosmic.doc` is present in every
artifact. Yet nothing documents this as a supported way for a project to
ship its own guides, and the one project that needs it does not use it:
cosmic-lua/work's `_work/doctrine.tl` (445 lines, 2026-09-05) holds every
`gitboard help <topic>` page as a Lua string in a `PAGES` table, with its
own `names`/`page`/`listing` (lines 396-418) reimplementing what
`cosmic.doc.guide_topics`/`guide`/`guides` already do for cosmic.

What is not yet known, and this item must settle: whether
`cosmic.doc.guide` works in a binary that carries `/zip/docs/guides` but
no `/zip/.docs/index.lua` (`query.tl:11`; `is_available` and the module
index are cosmic-only), and whether `--make`'s embed rules already accept
markdown under `embed/docs/` for a project or route it elsewhere.

## Change

1. Measure first, on a `_make/testdata`-sized fixture with
   `embed/docs/guides/hello.md`: build it, run
   `require("cosmic.doc").guide("hello")` from its binary. Record what
   happens (works / needs the index / the file is not embedded) in the
   PR.
2. Make it work: `guide`, `guide_topics`, `guides` read only
   `GUIDES_DIR` and never touch the module index, so a project binary
   with guides but no index serves them; a project with neither gets the
   existing "no guides available" error.
3. Document it: `cosmic --docs guide` (or the make guide) gains a short
   section "shipping your own guides" — put markdown under
   `embed/docs/guides/`, its H1 first line is the topic description,
   `cosmic.doc.guide(topic)` serves it, and `--docs guide.<topic>` on a
   cosmic-style CLI is what `cmd/<name>/main.tl` can wire to it.
4. Test: the fixture from step 1 becomes `_make/testdata/guides` and
   `_make/fixtures_test.tl` builds it and asserts the topic renders.
5. Then, on the work side (its own follow-up): `_work/doctrine.tl`'s
   pages become `embed/docs/guides/*.md`, `help <topic>` calls
   `cosmic.doc.guide`, and `doctrine_test.tl`'s "no topic shadows a verb"
   check reads `guide_topics()`.

## Non-goals

Changing the guide format or `--docs` output; a general documentation
system for project binaries beyond guides; the work-side port.
