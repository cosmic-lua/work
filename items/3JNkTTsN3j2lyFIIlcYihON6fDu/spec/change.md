An item filed by `new --spec-file` gets no `touches` field, so the spec
bar's own path measurement silently does not apply to it: `show` prints no
`tight:` line, and its builder brief's `## Measured at brief time` section
carries the header alone, with no rows.

Measured 2026-09-15, two items whose specs name the same file in the same
backticked form:

- «S4pF_DMGT», which carries `touches: _work/brief.tl _work/brief_test.tl
  _work/brief_review_script_test.tl`, produced `_work/brief.tl  493 lines
  (7 under the 500 cap)` in its builder brief.
- «bjHf_Ekuj», filed by `new --spec-file` with no `--touches`, carries no
  `touches` key at all and produced the bare header.

The consequence was paid immediately: «bjHf_Ekuj»'s builder drafted an
addition to `_work/brief.tl`, `--check lint` refused at 503/500, and it
spent an extra edit/measure cycle trimming. The file had 5 lines of
headroom, `briefmeasure.measure` knows how to render exactly that
(`_work/briefmeasure.tl:70-75` emits `(N under the 500 cap)` within 40
lines of the cap), and the number never reached the agent that needed it.

Derive `touches` from the spec's `## Change` when `new` writes an item, the
same way a caller would declare it by hand. `brief --tree`'s own help
already says it measures "Teal paths named by ## Change beneath DIR", so
Change-derivation is the documented contract; the behaviour is
`touches`-driven, and the two disagree. Make them agree. Deriving at `new`
needs no second field kept in step with a respec.

If instead `touches` is to stay an independently declared field, then
`brief --tree`'s help is what must change, and `new` must still prompt or
refuse rather than silently filing an item the measurement cannot see.

Note while touching this: `set --access OWNER/NAME` alone reported
`touches, access updated` on «ANCD_Nzw9» and left `touches` absent. Per
`help set` each flag "REPLACES its whole list", so a caller repairing one
field can silently clear the other. Worth a regression either way.

Regression: an item filed by `new --spec-file` whose `## Change` names a
Teal path renders that path's line count, and its cap marker when within 40
lines of the cap, in its builder brief.
