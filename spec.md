## Change

The design, so the children read as one thing. cosmic never
stabilizes; code written for it is always trivially upgradable. Three
sentences carry the whole mechanism:

1. A public name leaves cosmic with its wrapper: a function in
   `cosmic/_gone/<module path>.tl` with the OLD name and OLD type whose
   body is the new call. A record field or enum member that leaves, or
   a name with no replacement, leaves a `-- gone` line there instead.
2. The surface ratchet enforces it: the name-level public surface is a
   committed baseline, and a name that left it without its wrapper or
   line does not merge.
3. `cosmic --upgrade OLD` recovers a project: it diffs its own surface
   against the OLD binary's (both embed their `.tl/` sources), scans
   the project for every use of a name that left or was retyped,
   prints each with its wrapper's doc line, and with `apply` inlines
   the wrappers at the call sites.

Measured basis: the 2026-09-05 break-and-recover experiment and the
three-week surface-churn census are quoted in full in the D10
amendment item (`pmsp_heru`'s child) and the strict nil-flow evidence
item `55xyILjS`. The one number to hold onto: with wrappers inlined by
the tool, an agent upgrade of a five-file consumer across five breaks
took 4 cosmic invocations and 13 seconds, against 25–35 and 150–250
seconds with the binary alone.

Landing order is edges, not prose: `_tool/surface` + `--diff` first
(the extractor both the ratchet and the verb read); the ratchet and
gone tree behind it and behind the D10 amendment; `--upgrade` report
behind both; `--upgrade apply` last. The four are file-disjoint.

## Non-goals

No retirement schedule for wrappers in this pass: they are data-sized,
the per-release size report makes their weight visible, and a rule can
be added when the report says so. No compatibility commitment of any
kind. No codemod language: the transform is Teal.
