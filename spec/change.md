Ready when: `ls _perf/bench/http_server_bench.tl` prints `_perf/bench/http_server_bench.tl`.

That is the baseline child merged; a concurrency decision without a
single-connection baseline cannot be compared. Today the command
reports the path as missing.

Deliverables, no product code:

1. Measure: the fork cost per platform (a 20-line script under
   `_perf/` is fine, not committed unless it becomes a scenario), the
   baseline scenario's numbers, and the poll-loop shape's numbers from
   a throwaway branch if it can be prototyped in under a session.
2. Write `docs/decisions/d<next>-http-concurrency-model.md` per
   `skills/decide/SKILL.md`: the three options each with the reason it
   lost or won, the measured numbers, and the consequence for
   `Handler` (unchanged) and for what a handler may assume about
   shared state. This item's own Evidence section above cites the
   tree by inline `` `path:line` `` — do not carry those spans
   verbatim into the record: `--make lint`'s `doc-citation` rule
   refuses an inline citation in committed markdown (docs/guides/lint.md,
   "in a live document the form is refused outright"). Name the
   symbol in prose (`` `tool/net/redbean.c`'s `HandleMessages` ``) or
   requote as a fenced `-- path:line` citation instead.
3. File the build items under this container as children of this item's
   parent, ranked after it, file-disjoint where possible; for a fork or
   thread model the cosmopolitan-side binding is its own item with the
   `definitions.lua` rule named.
