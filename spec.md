## Change

`_work/spec.tl`'s `sections` ends a section at the next heading of ANY
level, so a `###` subheading inside `## Change` closes the Change
section and opens one keyed by the subheading's own text:

```
$ sed -n 46,52p _work/spec.tl
    local text = line:match("^#+%s+(.-)%s*$")
    if text then
      current = text:lower()
```

Nothing distinguishes `##` from `###`. `_work/overlap.tl`'s
`raw_paths_named` reads `change_section`, which scans the same way, so
every path a spec names under a Change subheading is invisible to
collision detection. Measured over the 1342 live spec sidecars,
**37 carry a backticked path under a `###` subheading of `## Change`**
— each one a collision the board cannot see.

The failure is silent and one-directional: a missed path is a missed
warning on `show` and `next`, never a wrong refusal, which is why it
has gone unnoticed.

1. `_work/spec.tl`: `sections` records each section's heading LEVEL
   alongside its lines, and a heading closes the current section only
   when its level is less than or equal to the open section's. A
   deeper heading's own text and lines belong to the section it sits
   under. A thematic break still closes any section, as now.
2. Keep the returned shape. `ready_gaps` and `declared_repos` read
   `sections(body)[name]` and must not change; the fix is that
   `["change"]` now contains its subsections' lines too.
3. `_work/spec_test.tl`: a case whose `## Change` carries a `###`
   subheading with a backticked path, asserting the path is in
   `sections(body)["change"]` and that no section is keyed by the
   subheading's text. A case with two sibling `##` sections still
   separates them.
4. `_work/overlap_test.tl`: the same body through `paths_named`,
   asserting the subheading's path is found. This is the behaviour the
   board actually lost.

## Non-goals

`_work/briefmeasure.tl`'s `change_paths`, which is a third, stricter
scanner with its own defects (level-2 only, exact case, blind to
thematic breaks). It is retired when `touches` is declared; widening it
here would be work thrown away twice.

A fence-aware scanner. A `###` inside a fenced code block is still read
as a heading after this change, exactly as before — a separate defect,
and the spec splitter that needs fence-awareness is its own item.

Deleting any of these functions. `touches` retires them later; this is
the fix for the board as it stands, because that retirement is several
items and a release away and the wrong answers are being given now.
