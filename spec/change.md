Three modes on `show`, each printing one thing and nothing else. The
default output does not change.

1. **New module `_work/gitshow.tl`.** Move `show_report` and
   `cmd_show` out of `_work/gitview.tl` — the block
   `sed -n '236,353p' _work/gitview.tl` (118 lines, doc comments
   included) — into it unchanged, drop them from `gitview`'s record
   and table, and require the new module from `_work/gitboard.tl`.
   The move is forced by capacity, not taste: `wc -l < _work/gitview.tl`
   is 495 at board head `46f3f43b`, five lines under the 500-line cap,
   so `show` cannot grow where it stands.

2. **`cmd_show` widens to `cmd_show(s: store.Store, id: string, mode:
   string, section: string): integer`**, where `mode` is one of:
   - `""` — today's report, byte-identical.
   - `"spec"` — the sidecar verbatim, no fields header and no history.
     An item with no sidecar fails: `<id8> has no spec`.
   - `"section"` — the one section `section` names, its heading line
     included. A section the sidecar does not carry fails:
     `<id8> spec has no section: <NAME>`.
   - `"fields"` — today's report minus the `--- spec ---` block and
     minus the history lines.

   The three are mutually exclusive; two or more together fail with
   `REFUSED: --spec, --section and --fields each narrow one read — pass one`.
   Every path still ends in the `gitboard-show:` verdict line
   `gate.verdict_line` already writes.

3. **`_work/spec.tl` gains `section_of(body: string, name: string):
   string`** — the named section including its heading line, `""` when
   absent. It matches headings exactly as `ready_gaps` already does
   (any heading level, case-insensitively on the heading text) and
   ends the section at the next heading or a thematic break, so the
   grammar has one implementation and `--section acceptance` and
   `--section Acceptance` name the same thing. `wc -l < _work/spec.tl`
   is 87, so it has the room.

4. **`_work/gitboard.tl`**: `show`'s flag list gains
   `{long = "spec"}`, `{long = "section", arg = "NAME"}` and
   `{long = "fields"}`, and the dispatch tail passes the mode and the
   section name through. `wc -l < _work/gitboard.tl` is 296.

5. **Tests**: new `_work/gitshow_test.tl` carrying the six
   `show_report` cases that move out of `_work/gitview_test.tl`
   (`grep -c show_report _work/gitview_test.tl` is 6) plus one case
   per new mode and one for the mutual-exclusion refusal;
   `_work/spec_test.tl` gains `test_section_of` covering a present
   section, an absent one, a lowercase spelling, and a section ended
   by a thematic break.
