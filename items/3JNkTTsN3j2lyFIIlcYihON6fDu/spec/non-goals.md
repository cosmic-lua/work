The bare-header rendering for an empty list is NOT in scope and is not a
defect: `_work/briefmeasure_test.tl:76-78`
(`test_measure_of_nothing_declared_is_the_header_alone`) states the reason —
"An empty declared list still carries the header, so a brief says what it
measured against even when there was nothing to measure" — and pins it. An
earlier revision of this spec called for removing that header; that was
wrong, and reversing a tested, reasoned choice is not this item's business.
Fix the empty list, not the rendering of one.

Not changing `overlap.headroom_lines`, `briefmeasure.measure`'s row format,
or the 500-line cap. Not changing what `show` prints for an item that does
carry `touches`.

Note for whoever builds this: `_work/brief.tl` is at 500/500 on main and has
no headroom. `_work/briefmeasure.tl` (90), `_work/briefmeasure_test.tl` (92)
and `_work/gitset.tl` (134) have plenty. If the change needs a line in
`brief.tl`, it needs a split first — say so and stop rather than trimming
prose to fit.
