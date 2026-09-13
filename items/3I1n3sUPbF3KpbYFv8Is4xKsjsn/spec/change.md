A whole-tree gate that fails on identical normalized function bodies.
Refinement correction to the imported issue, from the tree's own
mechanics: `--make lint` is per-file (`_cli/lint.tl`'s `lint_file`, one
path per call from `_cli/main_handlers.tl:340`, and `_cli/lint.tl` is at
448/500 lines besides), while every existing whole-tree gate is a
`_build/` test — the cast ratchet (`_build/casts.tl` +
`_build/casts_test.tl`) is the pattern to copy, TREES constant and all.
So:

1. **`_build/dupes.tl`** (new): the scanner.
   - Files: every `.tl` under `TREES < const > = {"_make", "_cli"}`,
     excluding `*_test.tl` and any path containing `testdata/`.
   - Body extraction is textual and rests on a gate: `fmt` enforces
     2-space indentation, so a top-level body spans from a line matching
     `^(local )?function ` to the next line that is exactly `end` —
     nested closers are indented and cannot match.
   - Normalization: strip `--` comments to end of line, drop blank
     lines, collapse runs of whitespace to one space; parse the
     parameter names out of the header line and replace word-boundary
     occurrences in the body with positional placeholders (`__p1`,
     `__p2`, …). Both observed defects were byte-identical under less.
   - Floor: a normalized body under **5 lines** is skipped. Measured
     basis, 2026-08-19 at `f420391`, comment/whitespace normalization
     over the same scope: 812 top-level functions, 9 duplicate groups,
     of which exactly one is non-test — a 4-line `fail` forwarder
     tripled across `_cli/build/{batch,steps,work}.tl` — and the
     historical `write_if_changed` normalizes to ~14 lines. Floor 5
     therefore exempts the trivial forwarder and starts the gate at
     ZERO findings with no allowlist, while catching every observed
     defect. Record the number and this basis in the doc comment.
   - Failure message names both sites and the remedy:
     `identical body at A:12 and B:34 — export one and require it`.
2. **`_build/dupes_test.tl`** (new): the gate (scan the tree, assert no
   findings) plus unit pins on the scanner run over inline fixtures: a
   true duplicate fails; the same body with different parameter names
   fails; two bodies differing by one statement pass; a 4-line body
   passes.
