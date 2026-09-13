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
