`_cli/visibility.tl` (or a sibling `_cli/lint/` rule if that file is
tight — measure `wc -l` first and say which): one directory-level
check run by `cosmic --check lint` over the tree — a directory
`cosmic/<name>/` containing at least one non-test `.tl` file and no
`init.tl` is a finding: `cosmic/<name>/: shards with no public parent —
add cosmic/<name>/init.tl re-exporting what outside callers need`.
`_cli/visibility_test.tl`: a fixture tree under `TEST_TMPDIR` with
`cosmic/x/a.tl` and no init → the finding; with `cosmic/x/init.tl` →
none; `cosmic/x/a_test.tl` alone → none. The rule's doc line in
`cosmic --docs guide.lint` (where the visibility rule is documented —
`git grep -n visibility -- docs/guides/`).
