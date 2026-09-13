`_make/imports.tl` (or wherever the source headers are parsed): a
separate `--- ref: <name>` header line declaring a git ref as an
input — its own header, NOT a token inside `reads:`, because the
pinned release's `reads_of_file` reads any `reads:` token as a path
and refuses the project on a cold build (measured 2026-09-02 by the
builder: `bin/cosmic --make build` from the pin fails with
"declares `reads: ref:origin/board`, which does not exist" on both
generations; the `ci` and `repro` lanes build cold). A header the
pinned parser ignores is how `--- env:` landed without a pin bump.
The ref's contribution to the content key is its current commit
(`git rev-parse <name>`, read once per graph build; absent ref keys as
empty and the test's own skip path handles it). `_build/doc_paths_test.tl`
declares `--- ref: origin/board`. A test in `_make/` renames a file
on a scratch ref between two runs and asserts the second run is not a
replay. Prove the cold build in the PR: `rm -f o/bin/cosmic &&
bin/cosmic --make build` succeeds from the pin with the declaration
present. Measure the cost of the extra `rev-parse` per declared ref
on a full `--make test` and record it in the PR.
