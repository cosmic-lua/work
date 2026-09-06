## Evidence

`_cli/visibility.tl` enforces `cosmic/doc/visibility.tl`'s rule: only
`cosmic.<name>` is public; a deeper `cosmic.<name>.<shard>` may be
required only from inside `cosmic/`. Three items landed `cosmic/ast/`
as shards alone — `ls cosmic/ast/` → `match.tl node.tl walk.tl` (+
tests), no `init.tl` — and each passed review, because no diff
required them from outside `cosmic/`. The first consumer,
`_cli/find.tl` («5P4r_VUqR»), hit the lint at its full gate after the
whole feature was built: 109 calls, ~211k tokens, and a stop-and-report
(2026-09-06). Every other multi-shard module has the parent:
`ls cosmic/*/init.tl` → `cosmic/fs/init.tl cosmic/proc/init.tl
cosmic/sandbox/init.tl cosmic/flags/init.tl`.

The lint runs per file and sees one require at a time
(`git grep -n 'reaches a cosmic-internal shard' -- _cli/visibility.tl`);
nothing looks at a directory as a whole.

## Change

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

## Non-goals

No change to the per-require rule, no auto-generation of `init.tl`.
