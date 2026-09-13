Four source files and the test call sites, all on the `board` branch,
all deletion.

**1. `_work/gitgraph.tl` (256 lines) — `cmd_new` loses the dead
gate.** A filed child always gets `phase = "backlog"` (line 43) and
`flow.LIMITS` has no `backlog` entry, so the gate at lines 60-70
(`vacated` read included) is unreachable — proven by mutation during
3IVKVXoO's review: neutralising the read leaves the whole suite green.
Delete the gate block and the `vacated` computation. With the gate
gone, `force`/`why` in `cmd_new` feed only `force_refusal` and
`forced_suffix` on a verb nothing refuses: remove both parameters from
`cmd_new` (and the `forced_suffix` call in its commit message).

**2. `_work/gitboard.tl` — `new` loses `--force`/`--why`.** The flags
at lines 81-82 (help text: "override the plan WIP limit" — provably
false) and the dispatch's two arguments go.

**3. `_work/gitgate.tl` (346 lines) — `wip_refusal` loses `vacated`.**
After (1), no live caller passes it (`grep -rn "vacated" _work/*.tl`
outside tests: only gitgraph 56-66 and gitgate's own signature/docs,
measured 2026-08-27). Delete the parameter, the `or vacated == to`
clause, the `vacated` paragraph in its doc comment, the mention in
`commit_and_publish`'s doc (line 91), and the record declaration.

**4. Tests.** `_work/gitgate_test.tl` (144 lines):
`test_the_merged_board_carries_the_wip_refusal` drops its
vacated-credit assertion (it exercised a credit with no live caller).
`fixture.file_item` loses its `force` parameter, and every call site
drops the argument — measured now: file_item appears 47 times across 8
test files plus fixture.tl's own 4 uses, and direct `cmd_new(` calls
outside its definition number 8. All mechanical one-line edits; the
"filled board" fixtures that passed `true, "test fixture"` simply stop
passing anything, since nothing they were escaping exists.
`gitverbs_test.tl`'s `test_a_decomposition_is_never_refused_by_a_full_board`
keeps its postconditions (the child lands, the parent de-phases) —
what changes is that no gate was ever in its way, which its comment
now says.
