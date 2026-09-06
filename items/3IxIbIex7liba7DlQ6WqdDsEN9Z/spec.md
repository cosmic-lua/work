## Evidence

`build-vmX5_zQH2-748ecc95` (2026-09-06) re-verified the spec's file-scope
before editing, per this repo's own "before the first edit, `wc -l` every
file the Change names" rule, and found the three files the `## Change`
names are already at or one line from the 500-line cap:

    _types/gentype_parse.tl  — 496/500 (4 lines of headroom)
    _types/gentype_render.tl — 489/500 (11 lines of headroom)
    _types/gentype_test.tl   — 499/500 (1 line of headroom)

Tracing the actual data flow (`parse_module` in `_types/gentype.tl`,
`FuncDecl` in `_types/gentype_types.tl` — neither named by the Change)
confirms an `overloads` field must additionally be threaded through
both of those unlisted files for `gentype_render.tl` to ever see it;
that part fits inside `gentype.tl`'s existing 500 lines by widening
existing lines, so it is not itself fatal.

The fatal part is the actual logic: by comparison to the nearest
analogous existing code (`test_errno_overload_render`, ~45 lines),
the builder estimates:
- `gentype_parse.tl` needs ~25-40 new lines (has 4 headroom)
- `gentype_render.tl` needs ~20-30 new lines (has 11 headroom)
- `gentype_test.tl` needs a ~45-line test case (has 1 line headroom)

The shortfall is 10-40x the available headroom in every one of the
three named files. The file-length cap is a hard gate with no
exemption for `.tl` sources ("no exceptions" per AGENTS.md; `.d.tl` is
the only carve-out, per D39). The builder made no edits (tree clean on
branch `3Ip8yA77` at `2c67295`) and stopped rather than widen scope to
a file split on its own judgment.

## Question

`vmX5_zQH2`'s `## Change` as written cannot land in these three files
without a file-length-cap-driven split (of `gentype_parse.tl` and/or
`gentype_render.tl`, and a new home for the added test case) — a
structural decision (which module absorbs the new logic, whether
splitting a `_types/gentype_*.tl` file is itself in scope for this
item or its own separate prerequisite item) that the spec, as written,
does not answer and a builder should not resolve unilaterally.

Options to evaluate in a respec:
- split `gentype_parse.tl` and/or `gentype_render.tl` into a
  sibling file (e.g. an `_overload`-suffixed module) as ITS OWN
  prerequisite item, then resume `vmX5_zQH2` against the split;
- find a smaller-footprint implementation shape that fits the
  existing headroom (e.g. a shared helper reused by both parse and
  render, rather than the ~25-45-line blocks estimated above);
- or re-scope `vmX5_zQH2` itself to name the split as part of its own
  Change, if a single item is still preferred over two.

## Non-goals

Not re-litigating the overload feature's value — the parent chain
already wants it; this is purely about where the added lines fit
under the file-length cap.
