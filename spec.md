## Evidence

Board item `9R8e_zA8Q` ("gitboard help new: --repo option text should note it
is refused on a root item") specced porting a help-text string from a
sibling PR on a stale predecessor branch. The spec's Evidence section
stated as settled fact that `new --repo` without `--parent` gets refused
as parentless — a claim inherited from the other branch, never re-derived
against `cosmic-lua/work`'s own `cmd_new`. It doesn't hold there: an
omitted `--parent` always resolves to the real board id
(`_work/gitgraph.tl:141-154`, `read.board(c)`), so `new` can never produce
the one parentless item the refusal actually guards.

Neither the first builder nor the first reviewer caught this — the ported
text was textually correct (matched the other branch verbatim), CI stayed
green (nothing tests a help string), and the first review's own mutation
test targeted the wrong file. It took a SECOND, adversarial reviewer
empirically calling `graph.cmd_new(...)` against a fresh board to
disprove the premise. Cost: a full extra round — build (90k tokens/43
calls) → review (125k/53) → rework (100k/46) → re-review (96k/33) —
against build+review (~200k/76) for a correctly-premised item of similar
size (`cBpk_Os62`, `OiQb_ry43`). Roughly 4x the token cost of one clean
round, from a single unverified factual claim.

The builder brief's step 1 already says "Re-run any measured commands
the spec names... a fact that breaks the Change's shape is a real
blocker: STOP and report it" — but "measured commands" in practice reads
as line numbers and counts (`wc -l`, `grep -c`), not a behavioral claim
like "X is refused." Nothing in the brief tells a builder to actually
exercise the described behavior before building against it.

**File location correction, 2026-09-07:** the builder-brief step 1 text
this item targets does NOT live in `_work/brief.tl`/`_work/brief_test.tl`
(that module only fills placeholders and requires its templates from
`_work/brieftext.tl`, per its own docstring). It lives in
`_work/brieftext.tl`'s `BUILDER` constant, with the matching pinned-text
test in `_work/brieftext_test.tl` — confirmed while building the sibling
item `«RXhD_TRHL»` (file-cap latitude), whose spec named the same wrong
files and whose builder had to grep the tree to find the real location
before editing. That item's PR (once merged) already touches
`_work/brieftext.tl`'s step 1 text for a different reason (file-cap
latitude) — read its diff first, since this item's own edit lands in the
same numbered step and should compose with it, not revert it.

## Change

`_work/brieftext.tl`'s `BUILDER` template, builder-brief step 1: when a
spec's Evidence asserts a BEHAVIOR ("X refuses Y", "Z is unreachable",
"the check fires when...") rather than a static fact (a line count, a
file's existence), the step explicitly requires reproducing that
behavior against the current tree before writing any code — not just
re-running `wc -l`/`grep -c` on cited lines. A premise that doesn't
reproduce is the same class of blocker as a Change that can't fit under
the file cap: STOP, report exactly what was tried and what happened
instead, and do not build against the unverified claim.

`_work/brieftext_test.tl`: a case asserting the rendered brief's step 1
names both re-running measured commands and reproducing described
behavior, not just the former.

## Non-goals

Not asking a builder to re-derive every sentence of a spec's Evidence —
only claims the Change's correctness actually rests on (the kind a
reviewer would mutation-test). Not changing the review brief's own
adversarial-verification step, which already does this; this closes the
gap on the BUILD side, where the false premise first had a chance to be
caught for a quarter of the eventual cost.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
