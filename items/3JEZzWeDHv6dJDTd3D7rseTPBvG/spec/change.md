Ready when: `ls docs/guides/htmx.md` prints `docs/guides/htmx.md`.

That is the guide child merged; an eval task before the guide exists
measures the gap the guide is meant to close, which is a different
experiment. Today the command reports the path as missing.

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
