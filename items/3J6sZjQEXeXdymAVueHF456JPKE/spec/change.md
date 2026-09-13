Implement one opt-in builder preparation receipt, produced only after worktree
preparation succeeds and consumed by brief. The receipt is caller-owned local
data, never a lease or remotely confirmed fact in its own right. No external
prerequisite is required for this narrowed slice.

1. Add _work/preparation_receipt.tl for the v1 codec and receipt-specific
   validation. Add _work/preparation_receipt_test.tl for pure codec tests and
   _work/preparation_receipt_flow_test.tl for isolated public-flow tests.
   No general output framework, automatic receipt search, new board field,
   new Git ref, or tracked receipt storage.

   The wire format is UTF-8-compatible byte text, one key=value per LF line,
   final LF required, fixed key order exactly:

       format=gitboard-builder-preparation-v1
       board-root=...
       board-mode=...
       board-remote=...
       item=...
       session=...
       claim-fact=...
       claim-control=...
       product-base=...
       product-root=...
       branch=...
       worktree=...
       bootstrap=...
       gitboard-command=...
       gitboard-cwd=...

   Values escape backslash, LF, CR, TAB as `\\`, `\n`, `\r`, `\t` respectively.
   Decode only these four escapes; reject dangling/unknown escapes, NUL,
   missing/extra/duplicate/reordered keys, missing final LF and wrong version.
   Split each line at its FIRST equals sign; equals inside values is literal.
   Require canonical re-encoding equality. Empty command and cwd together
   are valid and mean "not supplied"; all other fields are nonempty except
   board-remote, which is empty exactly in explicit local mode.
   This codec is not shell syntax: never source/eval the receipt.

   claim-fact is the full acquisition root SHA. claim-control is the full
   preparation-time current batch/control SHA, not an item bridge SHA.
   product-base is the full product commit SHA. Validate session with
   claimsession.is_id; use the existing item-id and full-commit vocabulary.
   branch is claim.branch(item, claim-fact), not a new naming algorithm.

2. Add worktree --receipt-out FILE, --gitboard-command TEXT, and
   --gitboard-cwd DIR in _work/gitcommands.tl and wire them in
   _work/gitboard.tl to trailing optional arguments of cmd_worktree.
   Existing callers without these arguments retain their behavior/signature
   compatibility. The command/cwd flags require --receipt-out and each other.
   Receipt mode refuses --review before product mutation. Receipt output
   must be a nonempty explicit path; do not support "-" as stdout.

   TEXT is one opaque caller-declared command prefix, preserved byte-for-byte;
   reject NUL, LF or CR. Never execute, tokenize or attest it. DIR must name
   an existing directory and is recorded as fs.absolute_path(DIR).
   These are explicitly "caller-provided invocation (not verified)".
   product-root is separately the actual repository_map-resolved SOURCE
   product checkout used by worktree, never inferred from this command/cwd.
   There is no claim that the supplied command actually launched this process
   or successfully produced this brief. If omitted, say invocation unspecified.

   Before worktree add, receipt mode additionally requires a valid minted
   session and the confirmation checks in step 3. Preserve all existing
   authority/input-commit/collision checks, bootstrap behavior and refusals.
   After final checkout/HEAD/identity/bootstrap/prepared-ref validation,
   populate the receipt from the existing resolved source checkout, actual
   branch/path, active claim, and returned bootstrap label; write FILE.
   Canonical absolute paths are recorded for board-root, source root and
   worktree. No runtime/digest is inferred from the bootstrap label or pin.

   Receipt writing occurs before the positive final verdict. A write failure
   returns nonzero using the existing "checkout created at PATH; preparation
   failed: REASON" shape and retains checkout/branch. Earlier failures do not
   write the receipt. FILE is caller-owned output: explicit replacement has
   the same fs.write semantics as brief --out; interrupted writes can leave
   a partial artifact, which the strict decoder must reject. Do not delete
   a caller's older output or auto-clean a failed checkout. No reusable
   "--receipt-only" or existing-worktree adoption path in this version.

3. Validate authority for receipt production and consumption without any
   push/fetch/refresh or board mutation. Refuse active draft/overlay state.
   Use current store.load plus the existing active_claim policy; factor
   active_claim into the new helper if needed, retaining its error semantics
   for all existing worktree callers.

   In receipt mode run gitfsck_claimbatch.problems(s), refusing on any finding
   with its diagnostic. This deliberate conservative whole-board check
   prevents partial multi-member confirmations and orphan batch objects from
   being promoted to receipt authority; optimize it in a separate item.
   Inspect gitclaim.list_prepared for a still-staged transaction whose
   batch.commit equals the selected item's CURRENT claim-control and refuse:
   caller must complete its existing refresh/confirmation workflow first.
   Do not infer confirmation from the receipt or locally prepared item heads.
   Remote-backed reads use configured canonical tracking refs only.
   Explicit local simulation is supported and labeled board-mode=local; a
   successful promote_local/confirmation is allowed, never called "remote".

   At consumption require exact matching board-root, mode and remote, item,
   supplied caller session, acquisition root and product-base. Decode the
   receipt's preparation-time control with claimbatch.read_state and require
   the same holder/root/base; require its batch still has the canonical ref
   under the existing fsck check. Apply the live lease check to CURRENT state,
   not the historical preparation-time deadline.

   A confirmed renewal under the same holder/root/base preserves the receipt:
   claim-control remains the historical preparation value and is labeled as
   such in the brief. Current control may differ. Drop, expiry, force/reclaim,
   different holder/root/base, missing historical control, draft or incomplete
   current confirmation refuse. Ordinary item metadata changes do not
   invalidate the receipt while these identity conditions remain true.
   Reacquisition requires a new worktree and new receipt; never rewrite an
   old receipt to claim the new acquisition.

4. Add brief builder ID --receipt FILE and --session SESSION (environment
   GITBOARD_SESSION fallback through claimcli.resolve_caller) in the same two
   CLI wiring files. The new flags are valid only for receipt-backed builder
   briefs; absent --receipt keeps all existing kinds and label behavior.
   Reject --receipt for review/research/refine/decompose. This is a first-
   preparation handoff, not receipt-based rework/adoption after editing.

   Validate receipt and live authority BEFORE any brief output/file write.
   In addition validate source product-root using repository_map.validate,
   worktree's exact Git toplevel, HEAD == product-base, symbolic HEAD branch
   == recorded branch, and that source/worktree share Git's absolute common
   directory (use rev-parse --path-format=absolute --git-common-dir).
   No source HEAD==base check: source may be ahead of the claimed base.
   Do not recompute the path from a guessed product root, search siblings,
   require a bin/gitboard file, or silently fall back after receipt refusal.
   An already-advanced, detached, moved/missing or unrelated checkout refuses.
   This is deliberately conservative; no bootstrap rerun or artifact audit.

   Fill BRANCH, WORKTREE, CLAIM_BASE and the session label from the validated
   receipt. Override the branch in rework context too if that context exists;
   do not globally replace strings in rendered text or in the user's spec.
   The final verdict names the recorded session and says "prepared session",
   not "claim it as"; do not mint another label on this path.
   --tree, if supplied on this path, must resolve to the receipt worktree;
   otherwise refuse rather than measure some other source checkout.

   In _work/brieftext.tl parameterize only the BUILDER preparation prose,
   leaving legacy text selected when no receipt is supplied. The receipt-backed
   text must show all decoded fields with explicit provenance, retain their
   bytes (use the canonical escaped receipt as a fenced block where necessary),
   identify claim-fact as acquisition, claim-control as preparation-time
   control, and show bootstrap as historical process status only.
   Replace the unconditional "o/ is warm, the pins are fetched" assertion on
   this path with: "Bootstrap status records process success or explicit
   skipping; runtime invocation, digest and artifact readiness are unverified."
   Include optional caller-provided command/cwd in that provenance block, not
   as executable instructions. Generic caller-owned gitboard examples stay
   generic; do not replace template command examples or the verbatim spec.
   Keep spec contents, friction prompt, --out handling and measurements intact.

5. Tests are part of this diff, not manual-only acceptance. Pure codec tests:
   round-trip spaces, equals, backslashes, LF/CR/TAB and UTF-8; every malformed
   case above; no evaluation of shell-looking values.
   Public-flow tests in the new sibling use existing fixture/claim helpers,
   committed local shell bootstrap stubs, and isolated temporary repositories.
   Cover a minted session -> prepared claim -> caller-controlled local-bare
   publication/fetch -> confirmed refresh -> worktree receipt -> builder brief.
   Claim production itself is unchanged; the receipt reads its confirmed
   record instead of requiring a caller to parse claim prose.

   Assert exact session/acquisition/control/base/branch/path identities,
   explicit local versus remote provenance, command bytes/cwd, and no minted
   replacement session or legacy branch in either normal/rework context.
   Use a mapped source path containing spaces and a different invocation cwd.
   Preserve the spec verbatim even when it contains template-like text.

   Refuse before checkout creation for unconfirmed preparation, partial
   multi-member tracking state, still-staged current batch and active draft.
   Refuse before brief output for wrong session/item/board/base/root/control,
   missing/wrong/detached/advanced checkout or mismatched --tree.
   Test same-acquisition confirmed renewal succeeds; expired/drop/reacquired
   claims refuse the old receipt. Warm versus fresh store/cache reads must
   agree. Do not depend on a developer's global Git identity.
   Cover bootstrap failure/explicit skip, receipt-write failure, malformed
   receipt, absent receipt compatibility, non-builder flag rejection, and no
   mutation/push/fetch by receipt validation. Restore mocks under pcall.

6. Exact production scope: new _work/preparation_receipt.tl,
   _work/gitworktree.tl, _work/brief.tl, _work/brieftext.tl,
   _work/gitcommands.tl, _work/gitboard.tl.
   Test scope: the two new siblings in step 1. Do not add a gitverbs adapter,
   edit claim/transport/fsck algorithms, or grow existing test files.
   Keep every file <=500 lines. Keep codec/validation/provenance formatting in
   the new helper so brief (461 lines) and dispatcher (473) remain thin.
   If the new helper exceeds the cap, the only permitted mechanical split is
   pure codec/record definitions into _work/preparation_receipt_codec.tl with
   its sibling _work/preparation_receipt_codec_test.tl; describe that split.
   No unrelated refactor, new cast or new public cosmic module.

   Run scoped types/format/lint, the new test siblings and existing
   brief_test, brief_out_test, brief_rework_test, gitworktree_test,
   gitworktree_review_test and gitworktree_bootstrap_test. Run coverage after
   final test edits and the full CI gate. Only measured changed-module rows
   and new helper rows may be added/updated in .cosmic-coverage; do not lower
   retained behavior or regenerate unrelated floors.
   Commit implementation before mutation tests. Bypass receipt/live-claim
   comparison and separately bypass actual checkout HEAD/branch validation;
   the new public-flow tests must fail. Restore exactly and rerun focused tests.
