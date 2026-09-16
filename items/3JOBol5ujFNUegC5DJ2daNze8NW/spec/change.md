Decide how `touches` derivation distinguishes the files a Change is ABOUT
from the files it merely CITES, and apply that decision. «yHA3_FOjD»'s
stated design — "re-derive `touches` in `spec` the same way `new` does" —
is falsified: doing it unconditionally destroys correct data.

Demonstrated on «yHA3_FOjD» itself, at head `ac2192b6180c`:

- Its Change cites three `.tl` paths in backticks as narrative evidence
  about a DIFFERENT item's incident: `_work/gitworktree.tl`,
  `_work/worktree_runtime.tl`, `_work/worktree_runtime_test.tl`.
- `spec.touches_from_change` over that same Change blob derives exactly
  those three.
- The item's real `touches`, hand-set after `new --spec-file` first
  mis-derived it from this same prose, is `_work/gitspec.tl
  _work/gitspec_test.tl _work/gitgraph.tl _work/spec.tl`.
- **Zero overlap.** Any `spec` write changing one word of the prose would
  replace the correct list with three unrelated files, silently.

That is strictly worse than the staleness «yHA3_FOjD» set out to fix: a
stale list is outdated, this one is wrong.

The obvious guard does not work, and was tested rather than assumed.
Gating on `#it.touches == 0` breaks «yHA3_FOjD»'s own primary regression
(17 of 19 pass, 2 fail), because an ordinary second respec also inherits a
non-empty list — one that was DERIVED, not hand-set. `touches` carries no
provenance: `_work/item.tl:80`, `:334`, `:408` store it as a plain
space-joined list, so nothing distinguishes "hand-set to correct a bad
derivation" from "derived last time".

This also bears on the landed `new`-side derivation («ihON_6fDu»): it
mis-derives the same way. The difference is that a wrong list at `new` is
correctable by hand and stays corrected, whereas re-deriving at `spec`
destroys the correction. Best-effort-plus-correction is a coherent design;
best-effort-that-overwrites-corrections is not.

Options, to be decided and recorded:

a. Give `touches` provenance — a flag or separate field for "explicitly
   declared" — and re-derive only over a derived list. Costs a schema
   change and a migration.
b. Derive only from a dedicated section or marker the Change carries, so
   citation and subject are syntactically distinct. Costs a spec-format
   change and touches every existing item's prose.
c. Re-derive at `spec` but MERGE rather than replace, keeping any path the
   old list held. Cheap, but a list can then only grow, and a file that
   genuinely leaves the Change never leaves the measurement.
d. Do not re-derive at `spec` at all; accept staleness and make it visible
   instead — for example `show` and the brief flagging that `touches`
   predates the current Change. Leaves «yHA3_FOjD»'s bug open by design,
   but honestly.

Pick one, say why, and implement it. Whatever is chosen must keep
«yHA3_FOjD»'s ordinary case working (Change A respecced to Change B reports
B) and must not clobber a correct hand-set list, and must carry a
regression for the live case above.
