# G7 activation: an htmx web-app eval task, G7's measured-by and win condition, and its rank — owner's decision, evidence attached

## Goal

G7 says of itself (`docs/goals.md:220-231`): "deliberately not urgent;
direction, not deadline; it stays low in the order until activated ...
measured by: not yet. when this activates, it is compared into the
order and gets eval tasks and win conditions like everything else."
Filing a server is activating it. This item holds the three things
activation needs, all the goal owner's call (`gitboard help system`:
"A rank change among OUTCOMES ... belongs to the goal owner"), with the
evidence a session can gather so the decision is one reading:

1. an eval task — the G1 instrument's way of seeing whether a fresh
   agent can build an htmx app from the binary alone;
2. G7's `measured by:` and `win condition:` lines;
3. G7's rank among outcomes (today: `rank: outcome 13 of 34`, from
   `gitboard show h5Bn_sH7B`).

## Evidence

The eval suite is frozen by version: `_eval/suite.tl:1` "exactly seven
tasks", `:15` `version = 1`, and "ids, metrics, and status are pinned
verbatim ... changing any of them is a version bump". So a new task is
a suite version bump, not an append. The task shape is
`_eval/tasks/child-tcp.md` (a brief, then `## Acceptance facts` — each a
command-checkable fact, with S-traps named).

Ready when: `ls docs/guides/htmx.md` prints `docs/guides/htmx.md`.

That is the guide child merged; an eval task before the guide exists
measures the gap the guide is meant to close, which is a different
experiment. Today the command reports the path as missing.

## Change

Owner's decisions; this item prepares them and lands whichever the
owner takes:

1. Draft `_eval/tasks/htmx-todo.md` — "build a single-binary todo app
   with htmx: list, add (fragment reply), delete, one SSE counter;
   `o/bin/todo` prints `READY <port>`" — with acceptance facts in the
   `child-tcp.md` shape (a `POST /todos` with `HX-Request: true`
   returns a body without `<html`; without it, one with; ten runs
   identical; `ci: PASS`). Bump `_eval/suite.tl` to `version = 2` with
   the eighth task, surfaces `http,htmx,template,sse`, metrics as the
   owner sets (`S,C,Y,G4` is the peer tasks' shape).
2. Draft G7's two lines for `docs/goals.md` for the owner to accept or
   rewrite — measured by: the eval task's score and
   `_perf/bench/http_server_bench.tl`'s readings, release over
   release; win condition: the eval task reaches `proven` and the
   served-requests number never regresses outside the noise floor.
3. Post the rank pair in the PR: G7 against the outcome directly above
   it, with one sentence for each direction; the owner's `gitboard
   rank` lands the answer and the goals.md list is rewritten in the
   same PR (`skills/work/decompose.md`, "how the result lands").

## Non-goals

- Deciding the rank. Proposing it.
- Running the eval round (the `agent-eval` skill, after the suite bump).

## Access

- cosmic-lua/cosmic: read+write (`_eval/`, `docs/goals.md`).
- cosmic-lua/work: the rank verb, owner-run.
