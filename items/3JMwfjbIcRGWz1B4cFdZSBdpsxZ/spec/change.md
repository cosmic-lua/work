`gitboard refresh --execute` is documented as the verb that fetches
("--execute fetches the publication destination before confirmation",
`gitboard help refresh`), but on a checkout that has not already fetched the
board refs it refuses without fetching anything. The format gate runs first,
so the one verb that can fetch the board refuses until the board has been
fetched. Every fresh clone must therefore run raw Git plumbing by hand.

Measured on a clone built to match what a session harness produces (default
branch only, no `refs/remotes/origin/state`, no `refs/heads/board/format`):

    git clone --single-branch --branch main <board> probe
    bin/gitboard refresh --execute --dir probe ; echo "exit=$?"
    no board format marker in this checkout — fetch it: 'git' 'fetch' '--atomic' 'origin' '+refs/heads/state:refs/remotes/origin/state' '+refs/heads/board/format:refs/remotes/origin/board/format'; `gitboard init` is only for a board that does not exist yet
    exit=1

    cd probe && git for-each-ref --format='%(refname)' | grep -E 'state|format'
    (no output — nothing was fetched)

The gate's path: `_work/gitboard.tl` calls `store.open(dir)` —
`grep -n "local s, serr = store.open(dir)" _work/gitboard.tl` — before the
dispatch branch `grep -n 'if d.command == "refresh" then' _work/gitboard.tl`,
so `--execute`'s fetch in `_work/snapshot_publish.tl`
(`grep -n "if execute_fetch and refs.board_mode" _work/snapshot_publish.tl`)
is never reached. `store.open` gates through
`grep -n "local startup, err = stateread_start.open(root)" _work/store.tl` →
`grep -n "local head, herr = format.state_head(root, snapshot)" _work/stateread_start.tl`
→ `grep -n "return nil, marker_missing(dir)" _work/format.tl`.

Make `refresh --execute` fetch the two board refs before the gate:

1. `_work/format.tl`: split the argv out of `fetch_hint`. That function today
   builds the argv and then quotes it — `grep -n 'local argv = {"git", "fetch", "--atomic", remote,' _work/format.tl`.
   Add `fetch_argv(dir: string): {string}` returning that argv unquoted, have
   `fetch_hint` call it and do only the quoting, and export `fetch_argv` on the
   module record. One argv, two callers; the refusal text does not change.
2. `_work/gitboard.tl`: in `main`, before the `store.open(dir)` call cited
   above, add a branch taken only when `d.command == "refresh"` and
   `d.parsed.switches["execute"]` is set. It runs `format.fetch_argv(dir)`
   through the same child-process helper the existing fetch uses
   (`prepared.execute`, `grep -n "local ok, err = prepared.execute(s.root," _work/snapshot_publish.tl`),
   ignoring a non-zero result so a genuinely unreachable remote still falls
   through to the existing refusal rather than a new one. Then continue into
   `store.open` unchanged.

The gate itself is untouched: the fetch precedes it, it does not replace it. A
checkout whose remote really has no `refs/heads/board/format` still lands on
`marker_missing` with the same wording, now after a real attempt.

Regression: `_work/format_fetch_argv_test.tl` asserts `fetch_argv` and
`fetch_hint` describe the same argv (the hint is the quoted join of the argv),
so the two cannot drift.

Headroom, measured: `wc -l _work/gitboard.tl` is 488 of the 500-line cap, so
the branch added there must stay small — the shape above is roughly six lines,
and anything larger belongs in `_work/format.tl` (224 lines) instead.
`_work/gitview.tl` is not touched. The one sibling item that also edits
`_work/gitboard.tl` is the `show --summary` rollup; land whichever is ranked
first and rebase the other, rather than holding both open against 12 lines of
headroom.

The new test file `_work/format_fetch_argv_test.tl` needs a `.cosmic-coverage`
row only if the gate asks for one; `_work/format.tl`'s existing row
(`grep -n '_work/format.tl' .cosmic-coverage` -> `{["covered"] = 80, ["total"] = 99}`)
moves as the new branch is exercised. Adjust that row alone, measured with
`bin/cosmic --make coverage`, and carry the measured basis with it — never
regenerate the whole floor.
