Measured 2026-09-16 running the top-10 token-efficiency list. Two items were
built; both specs carried one of these defects, and both cost the builder real
tracing before its first edit.

«jifZ_JzNb» — unsourced existence claim. Its Change asserts "The handoff knows
whether it fetched — it passes `--fetch` to `worktree` itself — so the brief
can state the prepared state rather than guessing at a cold one." True of the
BUILDER path, which records preparation in `_work/preparation_receipt.tl`;
false of the REVIEW path, which has no equivalent. The builder traced
`_work/gitworktree.tl` (`bootstrap`, `bootstrap_and_refs`), `_work/gitreview.tl`
(`briefs()`), `_work/briefcommands.tl` and `_work/brief.tl` to establish it.
Transcript: 52 tool calls, 830s, cache_read 6,084,480 — FIRST EDIT AT CALL 28.
The agent's own account: "~15 tool calls ... A one-line note in the spec itself
pointing at `_work/preparation_receipt.tl` being builder-only ... would have
saved most of this."

«Vi68_fUEj» — unbounded quantifier. Its Change says "Put it in the brief
templates' environment section so every spawned agent gets it", and its
Evidence says "Six agents in one session needed to be told this by hand"
without saying what kind of agents those six were. The builder spent ~15
minutes and a dozen greps/reads across both `brieftext*.tl` files tracing,
template by template, which roles run a long gate, which run a single test
file, and which never build at all, before concluding the plural meant "every
future BUILDER spawn". Transcript: 55 tool calls, 868s, cache_read 5,702,296,
first edit at call 14. The agent's own account: "'every spawned agent' reads
naturally as 'every kind of spawned agent' ... What would have prevented it:
the spec naming which agent role(s) the fix targets."

Both builders resolved the gap correctly and reported the reasoning, so
neither produced wrong work. The cost is entirely in calls and tokens spent
rediscovering what the spec could have carried in one line.