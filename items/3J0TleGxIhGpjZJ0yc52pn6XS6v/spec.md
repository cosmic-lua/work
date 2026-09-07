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

## Change

`_work/brief.tl`'s builder-brief step 1 (or wherever the "what to do"
list is generated): when a spec's Evidence asserts a BEHAVIOR
("X refuses Y", "Z is unreachable", "the check fires when...") rather
than a static fact (a line count, a file's existence), the step
explicitly requires reproducing that behavior against the current tree
before writing any code — not just re-running `wc -l`/`grep -c` on
cited lines. A premise that doesn't reproduce is the same class of
blocker as a Change that can't fit under the file cap: STOP, report
exactly what was tried and what happened instead, and do not build
against the unverified claim.

`_work/brief_test.tl`: a case asserting the rendered brief's step 1
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
