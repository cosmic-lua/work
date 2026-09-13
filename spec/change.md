`_build/doc_paths_test.tl`: replace the `_work/` prefix excuse with a
cross-branch check — a `_work/...` span must exist on `origin/board`
(`git ls-tree`/`cat-file` against the fetched ref, read once per run),
and when the ref is not fetched the case is skipped with a printed
reason rather than passing silently (CI fetches `board`? measure
`pr.yml`; if it does not, add `origin/board` to the checkout's fetch
in the `ci` lane, one line). Fail naming file:line and the missing
board path. The first run's report is the fix list.
