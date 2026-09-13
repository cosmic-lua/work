**The pick, of the three the capture named: option 1 — `check` accepts a
slice with no PR, reviewed against the item's recorded evidence.** The
skill on `main` already says so and the tool is the half that
disagrees. `skills/work/review.md` (lines 104–111 at `main`
`ec794d44`) reads: "a research slice (deliverable: recorded findings,
no PR) takes the same three verdicts: accept means re-running the
spec's acceptance checks against the tree ... then `done ID`, with no
move into `land` because there is nothing to merge." So no skill edit
is needed to settle the question, and options 2 and 3 are declined:
option 2 puts work state in two homes, and option 3 contradicts the
sentence above plus `decompose.md`'s "the research IS the slice".

The relaxation is EXPLICIT at the call site, as the capture required —
never inferred from a missing `--pr`, or a code slice whose author
forgot the flag would reach a reviewer with nothing to read.

All of this is on the `board` branch. Measured 2026-08-26 at `board`
`55024867`; every file is well under the 500-line cap:
`wc -l _work/gitboard.tl _work/gitverbs.tl _work/gitverdict.tl
_work/guidance.tl _work/gitverbs_test.tl _work/gitverdict_test.tl`
gives 333, 256, 226, 152, 335, 182.

1. `_work/gitboard.tl` — add `{long = "evidence", help = "hand over
   recorded evidence instead of a PR"}` to the `move` command's flag
   list (the block at lines 110–116, beside `claim`/`pr`/`force`/`why`),
   and pass `d.parsed.switches["evidence"]` through the `verbs.cmd_move`
   call at lines 286–287 as a new trailing parameter.

2. `_work/gitverbs.tl` — `cmd_move` grows that `evidence: boolean`
   parameter (update its signature, its doc comment, and the
   `GitVerbs` record entry that declares it). The refusal at lines
   97–100 (`"REFUSED: a handover to check names its PR — pass --pr N"`)
   becomes conditional: it still fires when `evidence` is false, and
   when `evidence` is true it is replaced by a refusal on the OTHER
   ground — the item's spec sidecar must carry a non-empty `## Result`
   section, read with the existing `spec.section_of(body, "Result")`
   (`_work/spec.tl`, already exported; no new reader). Refuse with a
   message naming what is missing, e.g. `"REFUSED: an evidence
   handover carries its findings — <id> has no ## Result section"`.
   The claim refusal at lines 103–108 is UNCHANGED: an evidence
   handover still names its builder, because the review distance is
   the same distance.

3. `_work/gitverdict.tl` — an `accept` on an item whose `pr` is 0 ends
   the item instead of parking it in `land`. Today `TARGETS["accept"]`
   is `"land"` (line 42) and nothing on the verdict path consults
   `gate.land_refusal`, so a PR-less accept lands in a phase where
   `gitboard land` refuses forever ("a move into land names its PR").
   Reuse the shape already there for an already-merged PR (lines
   184–199): set `target = "completed"`, `it.phase = ""`,
   `it.resolution = "completed"`, and call `gate.rephased_parent(it,
   all)` so a container whose last child just ended comes back to
   `backlog`. Say so in the verdict line — the merged branch appends
   `", merged <sha>"`; the evidence branch appends a note of its own
   (e.g. `" (evidence handover — nothing to merge)"`).

4. `_work/guidance.tl` — the `review` note (lines 30–36) tells the
   reviewer to read "the acceptance evidence in the PR description".
   Add one sentence: an item with no `pr` is an evidence handover —
   read its `## Result` section, and `verdict ID accept` ends it, with
   no move into `land`.

5. Tests. `_work/gitverbs_test.tl`: a move to `check` with
   `--evidence` and a `## Result` section succeeds; the same move with
   `--evidence` and no `## Result` is refused; a move to `check`
   without `--evidence` and without `--pr` is still refused as today.
   `_work/gitverdict_test.tl`: `accept` on a PR-less item in `check`
   ends the item (`phase` empty, `resolution` `completed`) rather than
   moving it to `land`.
