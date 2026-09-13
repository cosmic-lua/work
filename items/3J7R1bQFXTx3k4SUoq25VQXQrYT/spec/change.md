Make ordinary pinned-cosmic worktree creation cache-first, and add explicit
adoption of its exact retained builder checkout. One workflow, one item:
fresh creation and recovery call the same verified preparation tail.
Keep the common commands short:

    gitboard worktree ID --receipt-out FILE
    gitboard worktree ID --adopt EXACT_PATH --receipt-out FILE

Both use the existing session/environment and repository map. Add `--fetch`
only when the caller authorizes product dependency acquisition and, on a
verified-runtime cache miss, one bounded download of the target pin.
This flag NEVER means board refresh or Git object fetching.

1. Add `--adopt DIR` and `--fetch` in `_work/gitcommands.tl`, wire them
   through `_work/gitboard.tl` to trailing optional cmd_worktree arguments.
   `--adopt` requires nonempty DIR and `--receipt-out`, refuses `--review`,
   and is not an automatic collision fallback. Empty explicitly supplied
   flags refuse before mutations. Existing invocation-text flags remain
   opaque, optional, and unverified. No gitverbs change.

   The verified path applies to cosmic-kind targets with a tracked regular
   `bin/cosmic.pin`. Determine kind using repoprofile.resolve, unchanged.
   A present malformed/unreadable/nonregular pin refuses: do not downgrade
   to the launcher. Cosmic targets without a pin, Make-kind, cosmopolitan,
   and absent-kind targets keep today's default bootstrap behavior; both new
   flags refuse for those unsupported targets. Preserve explicit bootstrap
   skipping for ordinary legacy calls; adopt/--fetch refuse when
   GITBOARD_WORKTREE_BOOTSTRAP=0 rather than manufacture verified preparation.
   Do not integrate Make bootstrap or change default_base in this item.

2. Put bounded pin/cache/invocation code in new `_work/worktree_runtime.tl`.
   The expected pin is the TARGET commit's `bin/cosmic.pin`, never source
   HEAD's pin or the invoking gitboard's pin. Read its committed blob and
   require target working bytes equal it. Accept at most 16 KiB, no NUL,
   LF/CRLF physical lines, blank lines and ASCII-space/TAB-prefixed comments;
   exactly one `url = VALUE` and one `sha256 = VALUE`, in either order.
   Permit ASCII spaces/TAB around `=` and trailing whitespace only. Refuse
   unknown/duplicate keys, empty values, continuations, inline comments,
   non-HTTPS URLs, URL userinfo/control/whitespace, and non-lowercase-64-hex
   digests. This is data, never shell/config evaluation. Require the Git
   entry be regular mode 100644 or 100755; no symlink pin or submodule pin.

   Try only these candidates, in order: target `o/bootstrap/cosmic.ape`,
   target `o/bootstrap/cosmic`, source `o/bootstrap/cosmic.ape`, source
   `o/bootstrap/cosmic`. Source means repository_map's explicit resolved
   checkout; never enumerate siblings, other claims, PATH, home caches, or
   arbitrary caller runtime paths. Read regular non-symlink files only,
   bounded to 256 MiB. Hash actual bytes with cosmic.hash. A name, mtime,
   executable bit, `.pin` stamp, or self-reported version is not evidence.
   An assimilated binary is accepted ONLY if its actual bytes independently
   match the target pin; usually it will not, so try the pristine sibling.
   Print concise candidate rejection/cache-hit diagnostics without executing
   rejected bytes. Do not modify source caches or copy dependency/build trees.

   Copy the verified byte snapshot into a uniquely created, private directory
   below target `o/`, with a private executable file. Refuse symlink/non-directory
   output ancestors and any tracked or non-ignored intended output path;
   rehash the staged bytes before execution. Do not launch
   a mutable source candidate after checking it. Retain a verified pristine
   copy at target `o/bootstrap/cosmic.ape` by a uniquely created same-directory
   temporary write, rehash, then exclusive hard-link publication with
   `fs.link(temporary, destination)`, followed by `fs.remove(temporary)`.
   The temporary must be a separate byte copy, not a hard link to the private
   execution file. Never use fs.move/rename, remove the destination, or treat
   a prior absence check as exclusion: the destination can appear meanwhile.
   A successful link publishes those complete verified bytes without replacing
   an existing entry. Remove only this invocation's temporary name after every
   link outcome; a cleanup failure is a preparation error, never permission
   to remove the destination.
   On EEXIST (including a destination created by another preparer), leave the
   winner untouched and repeat the regular-file/non-symlink/size/hash checks.
   A valid winner satisfies cache publication; an invalid winner earns the
   existing rejection diagnostic and remains untouched while preparation uses
   its separately verified private execution file. Do not retry by replacing
   it. If the competing destination disappears or cannot be validated, report
   its rejection and continue with the private file, without a publication
   success claim. Other hard-link errors fail preparation after temporary
   cleanup; no rename/copy-overwrite fallback. For a destination already present
   before staging, apply the same validate-or-report policy without replacing it.
   Do not create an assimilation stamp or claim this copy is native ELF.
   The private execution file, not `o/bin/cosmic` or the repository launcher,
   is the command interpreter for this preparation run.

3. Probe only already-hashed staged bytes. First try argv
   `{RUNTIME,"-e",'io.write("gitboard-runtime-probe-v1\\n")'}`; if it fails,
   try `{"sh",RUNTIME,"-e",same_literal}`. A probe passes only for nonnil
   successful result, exact expected stdout including LF, and empty stderr.
   Preserve the successful argv prefix for every subsequent step; no eval,
   assembled shell command, version guessing, or unrelated interpreter.
   If neither works, report both failures and the preserved path; never
   fall back to the unverified launcher. These are two fixed probes, not
   arbitrary command execution to discover a runtime. Print the selected
   invocation as escaped data so host recovery no longer requires guessing.

   With no valid cache and no --fetch, fail promptly, listing checked paths
   and the target digest and naming `--fetch` as explicit acquisition.
   With --fetch, only AFTER exhausting those candidates, download the pin's
   URL into the private directory with one child argv:
   `curl -q --fail --silent --show-error --location --max-redirs 3 --proto =https --proto-redir =https --connect-timeout 10 --max-time 60 --retry 0 --max-filesize 268435456 --output PRIVATE_FILE URL`.
   No shell, curl config, alternate endpoint, release lookup, credential
   helper, exponential retry, or downloading any other runtime. Verify size
   and digest before probing/installing; failure is final for this invocation.
   Report product download explicitly before starting and preserve diagnostics.

4. Execute local build with the selected verified prefix and target cwd.
   With --fetch, first execute `PREFIX --make fetch`; otherwise do not execute
   a fetch step. Then execute `PREFIX --make build`. Derive the ordered cosmic
   plans from repoprofile and replace only their launcher argv element with
   this prefix; do not alter repoprofile's public contract.
   Missing dependency inputs in local-only mode fail honestly and suggest
   retrying the preserved checkout with --adopt/--fetch. Do not claim build
   failure proves missing dependencies when its diagnostic says otherwise.
   Rehash the private runtime before each step and before success.

   Preserve run_step's quiet summaries, verbose inherited streams, complete
   captured failure output, spawn/nonzero/signal failures. No successful final
   verdict or receipt after a failed step. A cache hit must precede any network
   acquisition. --fetch authorizes product acquisition, not remote board truth;
   gitboard itself runs no Git fetch/push/refresh/provider operation. Build is
   authorized repository code and may itself perform I/O: local-build mode is
   not an OS network sandbox. Help must state that distinction rather than
   promise universal offline execution. Do not add a retry after build failure.

5. Put adoption validation in new `_work/worktree_adopt.tl`. Before any
   product write/probe/build, reload the item and use receipt.confirmed with
   the current minted session: no overlay/draft/pending/unconfirmed/expired
   or different-holder claim. Compute the SAME branch and canonical nested
   path as fresh builder creation, using current acquisition root and exact
   product_base. --adopt must equal that path's exact absolute Git toplevel;
   reject alias/symlink paths, nested directories, unrelated repositories,
   detached HEAD, a different branch, and HEAD different from product_base.
   Require source and target's absolute Git common directories agree and
   `git worktree list --porcelain -z` registers that exact path/branch/HEAD.
   Source HEAD may differ; it is not authority for the claim base.
   Check both author and committer using the existing git-var policy; never
   copy/configure/print identities. Require clean index and tracked files,
   including submodule dirt, using Git status with untracked files omitted;
   never reset/stash or delete user changes. Untracked files are left alone;
   only named ignored preparation outputs are written by this workflow.

   Adoption never runs worktree add, checkout, reset, branch deletion, repair,
   or worktree pruning. Existing arbitrary paths are not legitimized by an
   old receipt. Renewals with the same acquisition/holder/base are allowed;
   reacquisition or a moved/edited checkout must refuse with an actionable
   reason. It can adopt a manually created worktree ONLY if every independent
   canonical claim/registration/checkout check passes; no hidden provenance
   marker is treated as authority.

   Fresh pinned creation and adoption then use the SAME runtime/preparation
   tail. Adoption skips creation and reuses only rehashed runtime bytes;
   fetch (when requested) and build remain incremental engine invocations.
   It must not erase warm outputs or force compilation. The engine determines
   missing/changed build work. Gitboard does not skip a step merely because an
   old receipt/stamp says PASS; zero rebuild work is not zero validation.
   No independent assurance about arbitrary generated artifact contents is
   claimed: repository-specific artifact attestation remains a separate item.

6. Immediately before any prepared-ref write and again before receipt/final
   success, reload and reconfirm current authority and recheck checkout
   HEAD/branch/common-dir/registration/clean tracked state/identity and pin
   bytes. Require acquisition/holder/base unchanged; renewal may advance
   control. Populate receipt from that final confirmed state. Reuse current
   prepared-ref resolution/recording; never fetch refs or change claim facts.
   For adopted checkouts, any final failure says
   `checkout retained at PATH; preparation failed: REASON` and preserves
   worktree/branch/older receipt. Fresh failure keeps today's `checkout created`
   shape and includes an escaped --adopt recovery example for builders.

   Emit exactly the existing v1 builder preparation receipt via receipt.write;
   preserve codec, keys, brief.read authority semantics and renewal behavior.
   Use an honest bootstrap process-status label, not invented runtime fields.
   Receipt output happens only after all validation/steps pass; existing
   caller-output write semantics remain unchanged. Do not reinterpret v1 as
   durable runtime attestation or attest caller gitboard-command text.
   Review creation gets cache-first preparation but still no v1 receipt or
   adoption. Preserve legacy no-pin/no-new-flag behavior and repeat refusal.

7. Add permanent isolated tests: `_work/worktree_runtime_test.tl` for cache,
   pin grammar, staging/invocation, mocked download and failures;
   `_work/worktree_adopt_test.tl` for authority/path/receipt public flows.
   Use real temporary Git products/boards and harmless committed runtime stubs
   whose bytes have fixture-owned pin digests. Real hash checks must run;
   never mock a corrupt digest into matching. Mock network execution only,
   recording exact argv/order. No real downloads or product builds in tests.
   Isolate Git global/system config and restore all env/print/child/fs mocks
   under pcall, including assertion failure. Cover:
   - valid source runtime and pristine .ape hits, wrong source pin vs correct
     target pin, assimilated mismatch, forged stamp, corrupt bytes, symlinks,
     missing candidates; no invalid runtime marker ever executes;
   - source changes after read cannot change staged execution; target runtime
     changes after probe are caught before another step/receipt;
   - deterministic concurrent-destination publication: interpose BOTH fs.link
     and fs.move for the final destination, creating a distinct sentinel AFTER
     the caller's absence check but immediately before delegating to whichever
     real publication primitive was called. Thus the overwrite mutant cannot
     bypass the race injection by avoiding fs.link. Assert sentinel bytes survive,
     rejection is reported, the private verified runtime remains separate, and
     the publication temporary is unlinked. Repeat with a matching-digest winner:
     it is accepted without replacement. Cover vanished/unreadable winners,
     other link errors and unlink failure; restore mocks with pcall. Also prove
     successful absent-only linking leaves correct cache bytes after temporary
     unlink. Replace exclusive fs.link publication with overwriting fs.move as
     a separate mutation; this concurrent-destination regression must fail.
   - both invocation forms, wrong probe output, both failed probes, signal,
     copy/hash/read/write failure, bounded exact curl argv, download digest
     mismatch, cache hit before network, no download/fetch absent --fetch;
   - successful fresh preparation -> failed build/receipt-write retention ->
     explicit adoption -> same branch/path/base/session v1 receipt -> existing
     receipt-backed brief success, with zero adoption worktree-add calls;
     an intact adopted build performs no forced rebuild/output deletion;
   - every wrong claim/path/registration/common-dir/head/branch/identity/dirty
     condition above; unchanged board refs/config/old receipt on refusal;
     expiry/reacquisition during bootstrap refuses final success, confirmed
     same-acquisition renewal succeeds using new control;
   - supplied refs only after successful validation, both verbosity modes,
     review cache creation, non-pinned compatibility and unsupported flags.

   Keep every production/test file below 500 lines. Exact source scope is
   gitworktree, gitcommands, gitboard, and the two named new production helpers;
   receipt/repoprofile/brief algorithms stay unchanged. Move only run_step and
   summary_of mechanically into worktree_runtime if gitworktree needs space;
   retain its legacy bootstrap adapter. If tests need a split, the only extra
   sibling is `_work/worktree_adopt_failure_test.tl`; no general fixture framework.
   Add measured new helper coverage rows and update only measured affected
   production rows; never reduce retained behavior or regenerate all floors.
   Run scoped types/format/lint, new siblings, all gitworktree test siblings,
   preparation_receipt test siblings and brief tests, coverage, then full CI.
   Commit implementation before separate mutations: bypass digest comparison,
   bypass adoption HEAD/branch validation, bypass final live-claim recheck,
   and permit download without --fetch. Each must fail its named new regression.
   Restore exactly and rerun focused tests; do not lower a floor to pass.
