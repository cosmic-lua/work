Retire the distinct result-only research-review template. Research review
requires the same exact product handover as ordinary review; it gains no new
board-read, provider, or verdict authority.

1. In _work/brief.tl's cmd_brief review selection, make handover_head the only
   positive eligibility signal. A nonempty result must never select a template.
   With a nonempty handover_head, run the existing ordinary full-versus-
   mechanical selection unchanged, even if legacy result is also nonempty.

   With no handover_head and a nonempty result, return a nonzero
   gitboard-brief refusal with this detail, substituting the actual id8:

   "ID8 has a legacy research result but no commit handover — the caller must
   supply the applying product commit with `take ID8 --head SHA`"

   Preserve the existing no-handover refusal for an item with neither field.
   Preserve preceding unknown-kind, tree, item, and missing-spec checks.
   Refuse before label/history resolution, body printing, measurement, or
   output-file writing. --out must neither create an absent file nor truncate
   an existing file on this refusal.

   No board fields or refs change while briefing. Do not clear result from a
   read or resolve it as a SHA. Existing item-wide round numbering remains
   unchanged, including historical verdict events with legacy result/PR subjects.

2. Remove RESEARCH_REVIEW's literal, record field, and returned export from
   _work/brieftext_review.tl. It is an internal template export: do not keep an
   alias that silently emits another workflow. The measured reference sweep
   names its entire current production use.

   Update only associated module/selection comments in _work/brief.tl and
   _work/brieftext_review.tl, and the two-reviewer-template description in
   _work/brieftext.tl's header, to describe full and mechanical exact-head review.
   Keep REVIEW and REVIEW_SCRIPT literal contents byte-for-byte unchanged.
   Keep the RESEARCH generation template and every non-review body unchanged.
   No "The board" paragraph, nested state path, sync recipe, new placeholder,
   extra board read, provider instruction, or alternate verdict command is added.

3. Replace the seven-line research paragraph at _work/doctrine.tl:340-346,
   rather than append to the 498-line file, with this seven-line paragraph:

   Research agents return recommendations; the caller applies them in the product
   repository and hands over its exact commit through `take ID --head SHA`.
   That commit must descend from the claim's product base. A result digest or
   unrelated board item-ref commit is not a substitute. If no applying product
   commit exists, no review brief is available: stop for caller preparation.
   Research uses ordinary exact-head review; no result-only review template
   or additional agent board-read instructions are emitted.

   This names the caller's preparation responsibility, not an instruction for
   the research agent to change the product or the board. The actual applying
   commit must be present in the declared/mapped product repository, have the
   required product-base lineage, and contain the deliverable under review.
   Do not infer it from a board ref, branch tip, result digest, or claim root.
   Existing gates perform their existing local checks; this item adds no new
   commit-validation rule or conversion mechanism. If a legacy item lacks an
   applicable product claim/base, the caller must establish an ordinary valid
   claim; do not bypass that contract or silently manufacture an empty commit.

   Leave general review/orchestration role wording outside this paragraph
   unchanged. The broader question of who invokes ordinary local verdict
   commands is not reopened by retiring the special research path.

4. Keep legacy data compatibility. Existing result/verdict_spec fields,
   item decoding, display/action compatibility, event history, and historical
   subjects remain readable and unchanged. Existing take_result/library
   compatibility is not removed or re-enabled through the CLI. No mass
   migration, schema bump, cache rewrite, or new flags.

   A caller migrates a result-only item through the existing ordinary handover:
   obtain the applying product commit under a valid claim and record
   take ID --head SHA. The existing take_handover clearing of result is reused,
   not reimplemented. A mixed result+head record can already produce ordinary
   review without mutating its metadata. Both cases retain their history.

5. Add _work/brief_research_test.tl for the new focused behavior, using existing
   fixture/commit_flow_fixture/storewrite helpers and a small local capture
   helper. This sibling avoids filling the 461-line brief_test file; do not
   extract a shared fixture framework or move unrelated tests.

   The new tests must enforce:
   - A valid legacy result-only fixture is still readable but cannot emit a
     review. Pin the actionable refusal and exit code, absence of a successful
     body, unchanged board refs/item fields, and no create/truncate for --out.
     A missing-spec fixture must still get the earlier missing-spec refusal.
     A result digest is never implicitly treated as handover_head.
   - The existing no-result/no-head refusal is unchanged; non-review research
     generation still works for a result-only item and retains its no-board-
     mutation instruction.
   - For both ordinary full and mechanical review, a valid head plus legacy
     result renders byte-identically to the same fixture after only result is
     cleared. The exact handed-over SHA appears in every verdict command,
     the stale-checkout warning remains, and no special capture-board-read or
     headless-verdict recipe is generated. Use a plain spec for these absence
     assertions; never strip quoted text from the caller's verbatim spec.
   - A real fixture sequence starts with legacy result metadata, passes through
     the ordinary claim/handover path, clears result, renders ordinary review,
     rejects a mismatched verdict head, and accepts the exact handover head.
     Also prove that a fetched, unrelated board item-ref commit fails the
     existing product-base lineage check. These prove the migration boundary,
     not a new production validation implementation.
   - The new doctrine paragraph states the caller preparation requirement and
     the no-product-commit refusal. The exported template table contains no
     RESEARCH_REVIEW key (inspect keys without adding an unsafe cast).

   Update only the three identified obsolete test assumptions:
   - brief_test.tl:342: replace the old successful headless-research assertions
     with a compact legacy-result refusal assertion. Keep its fixture helper;
     put the expanded coverage in the new sibling.
   - brief_review_script_test.tl:199: preserve the quoted-placeholder/survivor
     assertions, but give its review phase a real exact-head handover using
     that file's existing handover_diff helper. It must still prove the
     fully-filled ordinary review leaves no genuine placeholders.
     Remove the now-unused specmod import only if this conversion makes it unused.
   - brief_label_test.tl:138: keep all three historical verdict subjects and
     the -4 assertion. In the legacy-result phase retain the valid HEAD instead
     of clearing it; assert the same round through ordinary review. Do not
     weaken legacy event counting or non-review-label checks.

   Keep every modified/new file <=500 lines. The explicit source/test scope is
   the seven existing files measured above plus new _work/brief_research_test.tl.
   No new production module, public cosmic API, cast, or nullable-return
   signature is needed. No new ratchet row is expected from a new test file.
   If removal changes coverage denominators, only the mechanically affected
   _work/brief.tl or _work/brieftext_review.tl row in .cosmic-coverage may be
   updated from measured coverage. A row edit must not excuse lost coverage
   of retained executable lines; do not regenerate the whole baseline.
   The current rows are 73/84 and 4/6 respectively (measured with
   `rg -n -F -e '["_work/brief.tl"]' -e '["_work/brieftext_review.tl"]' .cosmic-coverage`).
   Other baseline movement is a finding, not authority to widen scope.

   Run scoped type/format/lint checks and affected test files. Because a template
   export is removed, run the normal build once before checking dependents.
   Run coverage after the final test edit, and the repository's full CI gate.
   Commit the real implementation before mutation testing. At minimum, bypass
   the legacy-result refusal and confirm the new refusal/no-output test fails;
   then force the presence of result to override a valid head (for example,
   refuse whenever result is nonempty even if a head exists) and confirm the
   mixed-field equality test fails. Restore exactly and rerun the focused tests.
