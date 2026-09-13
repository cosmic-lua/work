Make a non-accept verdict machine-checkable for its countermeasure, the same way
an accept is already machine-checkable for its first line.

**The grammar.** A `work-verdict: request changes` or `work-verdict: reject`
comment must carry, on a line of its own anywhere in the body, exactly one of:

```
enable: #1243
enable: none (the ready-bar gap was this issue's own; fixed in place)
```

`enable: #N` names the countermeasure issue. `enable: none (<why>)` is the
deliberate no-countermeasure case and requires a parenthesised reason. Nothing
else parses.

**`_work/verdict.tl`** — the pure half, mirroring `blocks_check` exactly:

1. Add `enable: string` to the `Verdict` record and to `Standing` (`:36`),
   populated by the same pass that reads the first line. Store the trailer's
   text verbatim, or `nil` when absent.
2. Add `blocks_send_back(s: Standing): string` beside `blocks_check` (`:145`),
   returning nil when the standing verdict is an accept, when no PR closes the
   issue, or when the trailer is present — and otherwise the refusal message,
   naming the PR, the verdict kind, and the two accepted trailer forms.

**`_work/verbs.tl`** — the call site, five lines, mirroring the `target ==
"check"` block at `:290`: when `target` is `do` or `plan` AND the issue is
leaving `check` AND not `--force`, call `verdict.blocks_send_back` and refuse
with `work-move: REFUSED (<message>)`.

Refusing the MOVE and not the comment is deliberate: a planner who has already
posted a verdict can post or edit a trailer in one step, so nothing is ever
stranded in `check`, and `--force` remains the repair path.

**`_work/verdict_test.tl`** — cases: trailer present with `#N`; trailer present
with `none (<why>)`; `none` without a reason REFUSED; trailer absent REFUSED;
accept with no trailer passes; no-PR passes; `--force` bypasses.

The facts this rests on, measured at `a3cd318`:

```facts
$ wc -l < _work/verbs.tl
495
$ wc -l < _work/verdict.tl
262
$ wc -l < _work/verdict_test.tl
192
$ grep -n "local function blocks_check" _work/verdict.tl
145:local function blocks_check(s: Standing): string
$ grep -n "record Standing" _work/verdict.tl
36:local record Standing
$ grep -c "enable:" _work/verdict.tl
0
```

**`_work/verbs.tl` has five lines of headroom (495/500) and the 500-line cap is
a hard gate.** That is why the predicate goes in `verdict.tl` (262 lines) and
only its call site goes in `verbs.tl`. A five-line call site fits; anything
larger does not, and growing `verbs.tl` is not in scope — if the call site
cannot be written in five lines, that is a bounce, not a refactor.
