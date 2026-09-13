`_work/gitgraph.tl:185`: the `new` verdict line leads with the handle
the way every rendered item line does — `tail.handle(it.id)` (the
helper `_work/gitview.tl`'s `id_line` uses) — followed by the full id
in brackets, then the rest unchanged:

    gitboard-new: «g0eF_1vae» [3Ixa3D2Q88OHSeGCfqcg0eF1vae] enters triage — rank it ...

`_work/gitnew_test.tl` (98 lines): the existing verdict assertion
matches the new shape, plus one case asserting the printed handle is
accepted by `show` (a round trip, so the two renderings can never
drift apart).
