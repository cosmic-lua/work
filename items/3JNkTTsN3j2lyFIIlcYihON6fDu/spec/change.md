An item filed by `new --spec-file` gets no `touches` field, so the spec
bar's own path measurement silently does not apply to it: `show` prints no
`tight:` line, and its builder brief renders

    ## Measured at brief time (<checkout>, <base>)

with an EMPTY body — a header promising measurements, delivering none.

Measured 2026-09-15, two items whose specs name the same file in the same
backticked form:

- «S4pF_DMGT», filed earlier with `touches: _work/brief.tl
  _work/brief_test.tl _work/brief_review_script_test.tl`, produced
  `_work/brief.tl  493 lines (7 under the 500 cap)` in its builder brief.
- «bjHf_Ekuj», filed this session by `new --spec-file` with no `--touches`,
  carries no `touches` key at all and produced the empty section above.

The consequence was paid immediately: «bjHf_Ekuj»'s builder drafted an
addition to `_work/brief.tl`, `--check lint` refused at 503/500, and it
spent an extra edit/measure cycle trimming. The file had 5 lines of
headroom, the board knows how to measure that (`overlap.headroom_lines`,
called from `_work/gitshow.tl:405`), and the number never reached the agent
that needed it.

Two things to settle, and the second decides the fix:

1. `brief --tree`'s own help says it measures "Teal paths named by
   ## Change beneath DIR". The behaviour is `touches`-driven, not
   Change-driven. Either the help is wrong or the implementation is. Make
   them agree. Deriving the paths from the `## Change` prose is the better
   half of that choice: it needs no second field to maintain, cannot go
   stale against a respec, and is what the help already promises.
2. An empty measured section must not render its header. A header with no
   body reads as "measured, nothing notable" — the opposite of the truth,
   which is that nothing was measured.

If `touches` stays as a field, `new` must derive it the same way `set`
already does — filing an item and then running `set` on it for an unrelated
reason should not be what turns the measurement on.

Note while touching this: `set --access OWNER/NAME` alone reported
`touches, access updated` on «ANCD_Nzw9» and left `touches` absent. Each
flag "REPLACES its whole list" per `help set`, so a caller repairing one
field can silently clear the other. Worth a regression whichever way 1 is
settled.

Regression: an item filed by `new --spec-file` whose Change names a Teal
path renders that path's line count and cap headroom in its builder brief;
and an item whose Change names no path renders no measured header at all.
