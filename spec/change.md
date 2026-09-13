Three edits, one rule.

**1. `_cli/citations.tl` — refuse the live inline form.** In
`check_citations`'s inline branch (`_cli/citations.tl:267-275`), a
recognized inline citation in a document that is NOT a snapshot produces
exactly one `doc-citation` finding and does not call `check_one`; a
snapshot document's inline branch is unchanged (`check_one` runs and
checks the path only, `_cli/citations.tl:177-179`). The rule applies to
every path, `o/`-prefixed ones included — a position nothing can read is
the objection, and a generated file's position is less readable, not
more. Keep the existing column (`line:find(span, 1, true) or 1`). The
finding's message, verbatim, formatted with the citing file, its line,
the citation text and the cited path:

    <file>:<line>: inline citation `<text>` pins a line nothing
    verifies — this check can only tell that <path> is that long. Quote
    it as a fenced citation (a `-- <path>:<line>` comment as the code
    block's first line, then the line itself, whose text is compared),
    or drop the `:<line>` and name the symbol in prose. A document
    describing a past commit says so with a `Measured against ` line.

Rewrite the module header comment (`_cli/citations.tl:11-17`), which today
says the inline form is checked "at the strength it admits"; it now says
the inline form admits no strength in a live document and is refused
there. Measured now: `wc -l _cli/citations.tl` is 288, 212 lines under the
500-line cap.

**2. The nine sites — drop the line span, name the symbol.** Keep every
sentence's substance; remove only the `:<line>` and, where the sentence
needed the number to point at something, name that something. Exactly:

- `docs/agent-usability.md:47` — `` `_cli/require_hints.tl:166` matches ``
  becomes `` `_cli/require_hints.tl`'s `is_module_not_found` matches ``
- `docs/agent-usability.md:62` — `` (source: `cosmic/poll.tl:41-46`). ``
  becomes `` (source: the `Poller` record in `cosmic/poll.tl`). ``
- `docs/decisions/d18-step-skip.md:98` — `` (`_tool/testrun.tl:54-68`), ``
  becomes `` (`_tool/testrun.tl`'s child-environment loop), ``
- `docs/decisions/d28-shape-combinators.md:10` — `` `_eval/score.tl:194`
  is the `` becomes `` `_eval/score.tl`'s `load_meta` is the ``
- `docs/decisions/d34-reproduction-against-remeasured-baseline.md:13` —
  `` `.github/workflows/release.yml:184`), `` becomes
  `` `.github/workflows/release.yml`'s perf-compare step), ``
- `docs/design/casts.md:55-56` — the two citations collapse into one path:
  `` `cosmic/json.tl` declares `decode_object(str): {string: any} | nil,
  string` and `decode_array(str): {any} | nil, string`, so a ... ``
- `docs/design/make/resolution.md:231` — `` `_perf/run.tl:163` is that
  case in this repo — `` becomes `` `_perf/run.tl`'s `load_module` is
  that case in this repo — ``
- `docs/guides/testing.md:132` — `` the precedent is
  `cosmic/net/connect_test.tl:247` (`net.listen_tcp("127.0.0.1", 0)`) ``
  becomes `` the precedent is `cosmic/net/connect_test.tl`
  (`net.listen_tcp("127.0.0.1", 0)`) ``

Reflow each paragraph to the house 90 columns after editing.

**3. `docs/guides/lint.md` — teach the rule.** Add a `## doc-citation`
section between `## visibility` (line 335) and `## running one rule's
worth of output` (line 344), in the shape the other sections use: what the
rule checks, the diagnostic, the fix. It must say that both forms check
the path, that only the fenced form compares text, that a live inline
`path:line` is refused, and that a document describing a past commit
declares itself with a `Measured against \`<sha>\`` line. Show the refused
form and its diagnostic inside an UNTAGGED fence (inline spans inside a
fence are never scanned, so the bad example cannot flag the guide), and
show the fenced form as this exact self-citation, which is stable and true:

    -- docs/guides/lint.md:1
    # Lint Rules

Measured now: `wc -l docs/guides/lint.md` is 353, 147 lines under the cap.

**4. `_cli/citations_test.tl` — the rule's tests.** Measured now: 171
lines, 329 under the cap. Six existing tests change verdict or message and
three must not move:

- `test_inline_citation_that_resolves` (`_cli/citations_test.tl:43-47`)
  asserts 0 findings for `` `src/sample.tl:2` ``, a path that exists at a
  line that exists. Rewrite it as **`test_live_inline_citation_is_refused`**:
  the same document must now yield exactly one `doc-citation` finding whose
  message contains `pins a line nothing verifies` and `fenced citation`.
  This is the mutation test — it fails before the change and passes after.
- `test_range_inside_the_file` and `test_generated_citation_is_skipped`
  flip from 0 findings to 1; rename each to say the inline form is refused.
- `test_inline_citation_past_end_of_file` and
  `test_inline_citation_naming_no_file` still assert one finding; their
  message assertions become the refusal message.
- `test_snapshot_leaves_positions_unjudged` (0 findings) and
  `test_snapshot_still_checks_paths` (one `names no file`) must NOT change
  — they are the guard against the rule over-firing on snapshots.
- The fenced tests, `test_prose_span_that_merely_contains_a_path` and
  `test_a_document_with_no_citations` are untouched.

If the coverage ratchet or the size ratchet complains, run exactly the
regen command the failure message prints and commit its result. Do not
weaken a gate any other way.
