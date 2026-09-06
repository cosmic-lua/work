## Evidence

Item «npTS_YYtP» was pulled, bootstrapped (`take` + `worktree`, ~2 min) and then ended not-planned: its `## Evidence` said "nothing gates them" of `-- throws:`/`-- exits:` markers, but `_cli/throw_lint.tl` (121 lines, cosmic-lua/cosmic#1681) has gated both token-exactly since before the item was filed, and `o/bin/cosmic --make lint` prints `lint: PASS (763 files)` on main 1cad490. The claim carried no command: the bar's evidence sentence ("every claim carries its command and pasted output") is read by refiners as applying to counts and measurements, and an ABSENCE claim — "no rule", "no test", "nothing gates", "not covered" — routinely ships as prose. The orchestrator now greps `_cli/ _build/ _tool/` by hand before every spawn; that is the step the tool should own.

## Change

One bar sentence in the bar doctrine (`_work/doctrine_bar.tl` or wherever `help bar` reads): an `## Evidence` sentence asserting an absence — "no rule", "no test", "nothing gates", "not covered", "never checked", "no gate" — carries the search that failed to find it, as a command and its empty or negative output (`grep -rn '<needle>' _cli _build _tool` → no lines, or `--make lint` → PASS). The bar check refuses a spec whose Evidence contains one of those phrases on a line with no fenced or backticked command within the same paragraph; the refusal quotes the phrase. Tests in the bar's test file: a paragraph with "nothing gates them" and no command is refused, the same paragraph followed by a backticked `grep … → (no output)` is accepted, and the phrase inside a `## Change` section is ignored.

## Non-goals

No change to what counts as a valid command; no retroactive check of ended items; no new verb.

## Access

cosmic-lua/work, read and write on a branch; no other repository.

## Ready when

`gitboard help bar` prints the absence sentence, and `take` on a fixture spec whose Evidence says "nothing gates them" with no command in the paragraph is refused with a message quoting that phrase, while the same spec with the grep pasted is accepted.
