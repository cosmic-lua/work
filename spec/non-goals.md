Do not touch the five non-regressing boundary entries —
`closure-fn-rvalue`, `closure-global-function`, `closure-local-function`,
`closure-local-macroexp`, `closure-record-function`. Their stock form
widened the continuation too; making them keep narrows would be a new
behaviour beyond stock, not a regression fix, and it belongs to its own
item.

Do not touch `closure-assigned-scan`, `closure-global-widen` or
`closure-root`: they are not boundary sites. In particular scope 1 stays
always-assigned inside `widen_all_unions` — a global's narrow still
drops for every closure BODY and at every loop site, which is what
`3IVL3BLT` (PR #1467) bought and `3IVQJa0b` (PR #1473) describes.

Do not touch the `["label"]` site — a narrow at a label must hold for
every goto path.

Do not change what a closure BODY sees. The chunk-root scan and the
rejected nearest-enclosing-body scope both stay as they are.

Do not memoize `assigned_anywhere` and do not restructure its scan for
speed. Measured and refuted 2026-08-27: 2925 calls costing 1.11 s of a
27.0 s `tl.process` run over 60 modules (4.1%); a per-`(root, name)`
memo recovers 1.3 percentage points and a one-pass assigned-names set
2.3, against a ±2 s run-to-run spread. Re-measure before reopening it.

Do not drop any `-- cast:` or `check.must` in the tree that the
regression forced. A source that only type-checks under the new rule
stages behind a release and a `bin/cosmic.pin` bump (see Enablement);
it must not land in this PR.

No new decision record. D21 already prices a carried patch as debt with
a re-audit at every pin bump, and the rule this change states lives in
`closure.tl`'s header comment, which is the place `skills/decide` sends
a rule a comment can carry.
