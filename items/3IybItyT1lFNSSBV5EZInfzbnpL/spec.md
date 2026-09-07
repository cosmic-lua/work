## Evidence

`docs/design/cast-sites.tsv` keys a site by `(path, fn, n)` where `n` is the cast's ordinal within its function (cosmic#1770). Inserting a cast ABOVE its siblings in the same function shifts every sibling's `n` by one: the aAVJ_FXDR builder added `pv as Node` before four existing casts in `cosmic/ast/match.tl`'s `compile_pattern` and `--reconcile` carried the four classes forward onto the wrong rows — harmless only because all five share the class "tl compiler surface" (builder report, cosmic#1777). `_build/cast_sites.tl`'s header explains the key but not this shift; `--reconcile` prints nothing about it.

## Change

`_build/cast_sites.tl`: `--reconcile` detects an ordinal shift — a function whose committed rows' `cast` texts all still exist but at `n+1` — and, rather than carrying classes by key, re-keys the shifted rows by their `cast` text and reports one line per function (`cast_sites: <path> <fn>: <k> row(s) re-keyed after an insertion at n=<m>`); a shift whose texts do not all match is a refusal naming the function. Header prose states the rule. `_build/cast_sites_test.tl`: a fixture inserting a cast before two differently-classed siblings keeps each class on its own text.

## Non-goals

No change to the key itself or the tsv's columns.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.

## Ready when

The fixture with two differently-classed siblings and an inserted cast reconciles with each class still on its own cast text, and the reconcile output names the re-keying.
