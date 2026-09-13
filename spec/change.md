Make review labels a deterministic ITEM-WIDE completed-verdict counter.
This replaces PR-scoped counting; it deliberately does not reset at a new
handover head. Rework normally changes the head, so current-head counting
would reproduce the round-one collision this item fixes.

1. Add `_work/brief_label.tl` as the cap-safe extraction of the existing
   LABEL_KIND/mint_label section and its session dependency from
   `_work/brief.tl`. Preserve the exact unsuffixed base-label behavior,
   including kind mapping, session.resolve(nil), first-eight identity
   characters, and the existing empty-prefix fallback. Preserve the
   existing exported `brief.mint_label(kind, handle): string` signature
   and its unsuffixed result by delegation. Update the moved documentation
   to distinguish that base formatter from the history-aware review label.
   Do not extract unrelated template, measurement, or review-selection code.

2. In the new helper, obtain review history through the existing
   `publish.history(s, it.id)` item-scoped read. For each returned event,
   use the existing `events.parse_subject(event.subject).verb`
   classification. Count exactly those events whose verb equals
   `"verdict"`, once per returned event. Do not deduplicate by product
   head, session, abbreviated event SHA, verdict kind or PR number.
   Do not parse head prefixes, consult current scalar verdict fields, query
   the events table directly, or introduce a second Git-history reader.

   Let n = count + 1. For n=1 retain
   `review-<handle>-<orch8>` exactly. For n>1 append `-<n>` in decimal,
   e.g. two prior verdict events produce `review-<handle>-<orch8>-3`.

   This count is over the lifetime history of this item ID. It does not
   reset on new handover heads, request changes, reject, cleared standing
   verdicts, URL edits, drop/reclaim, spec edits, a new orchestrator session,
   or a switch between commit and research review. A different item starts
   its own count. Repeated briefs against unchanged history return the same
   label: generating a brief does not allocate/reserve or increment a round.
   Failed/refused verdict attempts add no persisted event and do not count.

   Include legacy PR-keyed verdict events and historical result/research
   verdict events when the existing parser classifies their leading verb
   as `verdict`, even when their head is empty. Do not filter by
   `it.pr`, `it.result` or `it.handover_head`. Subjects the parser
   classifies otherwise (including `board:`, prose containing “verdict”,
   and take/spec/drop events) do not count. This is backward-compatible
   history consumption, not restoration of legacy PR/result verdict APIs.

3. Integrate the history-aware helper only in cmd_brief's `kind == "review"`
   path, after its existing item/spec/handover checks and before filling or
   writing the brief body. Both commit-review templates and the existing
   research-review template use the same rule. Resolve the label once and
   reuse that exact value for REVIEW_SESSION, embedded verdict commands,
   the closing claim-it-as label, and the brief content emitted through
   --out. Do not change the caller's output filename.

   A history read failure must return a nonzero `gitboard-brief:` refusal
   containing the underlying error; do not print a successful brief,
   truncate/write the requested output file, or silently mint round 1.
   Non-review kinds must not acquire a history read at all.

4. Add `_work/brief_label_test.tl` for the new label-focused coverage,
   following the existing sibling-test-file precedent. Leave the existing
   `_work/brief_test.tl` tests in place; do not relocate unrelated cases
   or create a shared fixture framework. Use existing fixture/storewrite
   helpers and a small capture helper local to the new test file.

   The new tests must enforce:
   - Zero prior verdicts gives the exact unsuffixed label (not a prefix
     match that would also accept a trailing -1); two verdicts gives -3.
     Check body session, embedded verdict command and closing claim label,
     including --out output, against the SAME exact expected label.
   - Two verdict events on different heads still give -3 after a new
     handover clears the standing verdict; non-verdict events between
     them do not affect the round.
   - The specified mixed legacy PR/result/current-head classification,
     same-head separate verdict events, and parser-classified non-verdict
     subjects. Historical subjects can be seeded by fixture store writes;
     do not call disabled legacy production verdict commands.
   - Research-review uses the same item-wide counter; non-review labels
     remain unchanged even when verdict history exists. Repeated reads
     do not change board refs or increment the label.
   - The existing history reader's cold Git fallback and warm-cache path
     produce the same label. A forced history-reader error causes the
     required refusal/no-output-file-write behavior; a non-review brief
     still works with that reader forced to fail.
   - Existing session-prefix behavior and the compatibility formatter
     remain unchanged.

   Keep every changed/new file at or below 500 lines. The explicit scope is
   `_work/brief.tl`, new `_work/brief_label.tl`, and new
   `_work/brief_label_test.tl`; the sibling files are the justified split
   from the original literal file list. No public cosmic module is added.
   New helper failures must use honest nullable two-slot return signatures;
   no existing ratchet baseline is expected to widen.

   Commit the real change before mutation testing. At minimum, force the
   review round to 1, verify the diff's -3 assertion fails, then restore
   exactly. Also demonstrate that filtering verdicts to the current head
   breaks the cross-head regression. Run focused checks/tests, coverage
   after the last test edit, and the repository's normal full gate.
