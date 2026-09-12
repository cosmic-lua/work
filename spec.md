## Evidence

`_work/review.tl`'s `head_moved` is exact equality:
`judged ~= "" and judged ~= (p.head_sha or "")`. Its sibling
`head_refusal` in the same file documents the opposite convention — a
caller "may pass a short sha, so the true test is a PREFIX match".

Nothing at `head_moved`, or at its new call site in `_work/ghland.tl`'s
arming guard, says which convention applies there. `46lA_bIVt`'s reviewer
had to trace `gitverdict.cmd_verdict_commit` → `commit_evidence.verify_lineage`
→ `commit_id` (`git rev-parse --verify <x>^{commit}`, lowercased) to
establish that the value arriving at the guard is already canonical full
hex, so exact equality cannot misfire on an abbreviation. That was about
four tool calls spent ruling out a hazard that does not exist, and every
future reader of that guard pays the same toll.

The same review noted the guard's fail-closed property rests on
`gitverdict` canonicalizing `head`, not on anything local to `ghland`: a
future caller of `ghland.land` passing `""` would silently re-open the
hole the guard exists to close, because `head_moved`'s `judged ~= ""`
short-circuits to false. Nothing in the tree does this today.

Separately, when a 405's follow-up read carries no `head` object,
`gh.pull` sets `head_sha = ""`, and the refusal renders as `the accept
judged 1469382 and the request's head is now , so auto-merge was not
armed` — `(p.head_sha or ""):sub(1, 7)` is empty. The behaviour is right
(a headless read is treated as moved, which is fail-closed); only the
sentence reads as though a word went missing.

## Change

Give `head_moved` a docstring clause stating what its `judged` argument is
expected to be — a canonical full sha — and that a caller holding a
possibly-abbreviated sha wants `head_refusal`'s prefix match instead. State
the empty-judged-head behaviour explicitly, so a reader sees that passing
`""` disables the check rather than having to derive it from the
short-circuit.

In `_work/ghland.tl`'s arming guard, render a headless read as something
that reads as a sentence — naming that the request reported no head, rather
than interpolating an empty string where a sha belongs.

## Non-goals

Not changing `head_moved`'s semantics, and not adding a runtime assertion
that `judged` is canonical — the verb's existing refusals already make an
empty head unreachable from the live path, and this item is about saying so
where it is read. Not touching `head_refusal`.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
