## Evidence

Every verb accepts an item by its handle — the id's LAST 8 characters,
rendered «g0eF_1vae» — and `show`/`next`/`find` print handles
everywhere. `gitboard new` alone answers with the full id:
`_work/gitgraph.tl:185` `("%s enters %s"):format(it.id, entered)` →
`gitboard-new: 3Ixa3D2Q88OHSeGCfqcg0eF1vae enters triage`. Reading the
handle off a 27-character KSUID by eye is error-prone: on 2026-09-06
(work4) the orchestrator read 7 characters, and `attach`, `brief` and
`take` each refused with `no item matches 0eF1vae` — three wasted
calls before retrying with the full id. `take`/`attach` print the
branch name (the id's FIRST 8) in their verdict lines, which is a
different string again.

`wc -l _work/gitgraph.tl` → 386.

## Change

`_work/gitgraph.tl:185`: the `new` verdict line leads with the handle
the way every rendered item line does — `tail.handle(it.id)` (the
helper `_work/gitview.tl`'s `id_line` uses) — followed by the full id
in brackets, then the rest unchanged:

    gitboard-new: «g0eF_1vae» [3Ixa3D2Q88OHSeGCfqcg0eF1vae] enters triage — rank it ...

`_work/gitnew_test.tl` (98 lines): the existing verdict assertion
matches the new shape, plus one case asserting the printed handle is
accepted by `show` (a round trip, so the two renderings can never
drift apart).

## Non-goals

No change to any other verb's verdict line, and no change to the
branch-name convention `take` prints.
