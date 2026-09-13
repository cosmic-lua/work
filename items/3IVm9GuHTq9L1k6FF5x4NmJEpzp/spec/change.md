Two files on `main`, delivered as PR 1462 (already open and green;
this item joins it to the board for review).

**1. New `skills/work/loop.md`** — the standing-loop chapter:
- one pass, right to left: sync + reconcile the previous wave, land,
  at most ~one inline review (never fanned out), fill the wave by
  claiming first and spawning agents in the background, fall back to
  intake, then report and end — never waiting inside a pass;
- minted identities: agent claims are `<session>/<suffix>`, and the
  verdict wall — a session never judges work its own wave built;
  `built_by` cannot see the relationship yet, so the wall is prose
  here and the machinery half is 3IVJVZJt;
- a stall table mapping every refusal a loop hits to its non-blocking
  answer, with find-before-file dedupe for captures;
- the report: a one-line-per-action ledger, with `/loop` no-op
  semantics for quiet passes.

**2. `skills/work/SKILL.md`** — the chapter joins the list with a
pointer beside `parallel.md`'s, the frontmatter names the `/work N`
invocation, and the board-in-one-minute CAS paragraph now tells the
drop-and-re-run story the board branch's publish rewrite landed
(a lost race drops the mutation whole and names the re-run; a
rejection with the remote unmoved is policy and keeps the commit
local) — the follow-up that rewrite's PR promised on `main`.
