## Evidence

This refinement narrows the original cache-first proposal to independently
checkable worktree preparation postconditions: the created checkout's exact
commit, effective Git identity, and the bootstrap subprocess result.
It does NOT implement verified caches, runtime selection, or repository-specific
artifact readiness. Those remain explicit follow-up prerequisites below.

Measured in the claimed cosmic-lua/work checkout at product HEAD
583be716f8fb3fa6ee6bb440f538f1f0cb2045f6:
`git status --short` was empty.
`wc -l _work/gitworktree.tl _work/gitworktree_test.tl
_work/gitworktree_review_test.tl _work/gitworktree_bootstrap_test.tl`
reported 360, 499, 277, and absent respectively.
`rg --files -g AGENTS.md -g SKILL.md` returned no paths.

The failure seam is exact:
`rg -n 'run_step|bootstrap\\(|bootstrap_and_refs' _work/gitworktree.tl`
locates run_step at 128, bootstrap at 156, bootstrap_and_refs at 212,
and its builder/review calls at 341/277.
`sed -n '118,172p' _work/gitworktree.tl` shows that run_step discards
both spawn failure and nonzero exit, while bootstrap returns the positive
"cosmic (local build)" label anyway. The --verbose path discards the result
just as the quiet path does.

A no-write in-memory probe of the warm compiled module demonstrated all four
cases. It substitutes only child.run, fs.is_file, and env.get in that process;
it neither invokes gitboard mutations nor creates a checkout:

```
sh o/bootstrap/cosmic -e 'package.path="o/?.lua;"..package.path; local w=require("_work.gitworktree"); local function up(f,n) for i=1,100 do local k,v=debug.getupvalue(f,i); if k==n then return v end; if k==nil then break end end; error(n) end; local boot=up(w.cmd_worktree,"bootstrap_and_refs"); local child=require("cosmic.child"); local fs=require("cosmic.fs"); local env=require("cosmic.env"); fs.is_file=function() return true end; env.get=function() return nil end; for _,verbose in ipairs({false,true}) do for _,spawn in ipairs({false,true}) do child.run=function() if spawn then return nil,"probe spawn failure" end; return {ok=false,code=17,stdout="",stderr="probe exit 17"} end; local label,err=boot("/in-memory-only",{},verbose); print(string.format("verbose=%s spawn_failure=%s label=%q error=%q",tostring(verbose),tostring(spawn),label,err)) end end'
```

Output:

```
probe exit 17
verbose=false spawn_failure=false label="cosmic (local build)" error=""
verbose=false spawn_failure=true label="cosmic (local build)" error=""
verbose=true spawn_failure=false label="cosmic (local build)" error=""
verbose=true spawn_failure=true label="cosmic (local build)" error=""
```

The repository resolver is path-only:
`sed -n '1,100p' _work/repository_map.tl` shows validate(path) and
resolve(board_root, repository, override). It exposes no artifact,
capability, cache, or runtime descriptor. `rg --files _work |
rg 'repo|mechanic|bootstrap|artifact|runtime'` returned only
repository_map.tl and repository_map_test.tl.
`sed -n '55,145p' bin/cosmic` shows the separate raw-download,
assimilated-runtime, and stamp scheme. Do not design a substitute here.

Git identity can be validated without guessing it or writing source
configuration. In this linked checkout,
`git rev-parse --git-path config` returned the same common-directory
config named by `git rev-parse --git-common-dir` plus "/config".
Ordinary linked worktrees therefore use shared repository-local configuration;
blind "copying" with git config --local would write that shared source config.
Per-worktree overrides may differ, so validation must also run in the newly
created checkout rather than assuming the source identity propagated.

This read-only probe used Git's own identity validator, with explicit test
configuration and cleared author/committer environment overrides:

```
sh o/bootstrap/cosmic -e 'local child=require("cosmic.child"); for _,key in ipairs({"GIT_AUTHOR_IDENT","GIT_COMMITTER_IDENT"}) do for _,valid in ipairs({false,true}) do local r=assert(child.run({"env","-u","GIT_AUTHOR_NAME","-u","GIT_AUTHOR_EMAIL","-u","GIT_COMMITTER_NAME","-u","GIT_COMMITTER_EMAIL","git","-c",valid and "user.name=Refinement" or "user.name=","-c",valid and "user.email=refinement@example.test" or "user.email=","var",key})); print(key.." explicit_identity="..tostring(valid).." exit="..r.code) end end'
```

Output:

```
GIT_AUTHOR_IDENT explicit_identity=false exit=128
GIT_AUTHOR_IDENT explicit_identity=true exit=0
GIT_COMMITTER_IDENT explicit_identity=false exit=128
GIT_COMMITTER_IDENT explicit_identity=true exit=0
```

Tests need explicit fixture identity: `sed -n '25,58p' _work/fixture.tl`
shows that the fixture isolates global/system config, but its git helper
passes user.name/email only via -c for individual setup commands. Those
overrides do not configure the product checkout used by production child.run.
Read the existing fixture seams with
`sed -n '1,180p' _work/gitworktree_test.tl` and
`sed -n '1,155p' _work/gitworktree_review_test.tl`.

The capped test has a safe, measured cleanup seam:
`rg -n -F -e '_make_sibling_checkout' -e '_with_invoking_checkout' _work`
returns only the two definitions at gitworktree_test.tl:105 and :133.
They are unexported, unused helpers for the retired sibling-discovery path.
Their complete adjacent comment/function block occupies lines 94–144,
immediately before claim_as's comment. Removing only that dead block supplies
space for deterministic fixture identities without moving live tests or
creating a shared fixture framework.
`rg -n 'bootstrapped cosmic|bootstrapped |bootstrap:'
_work/gitworktree*test.tl` found one old output assertion, at
gitworktree_test.tl:269, in the explicitly skipped-bootstrap test.

`bin/gitboard help bar` was absent (exit 127). Its read-only local equivalent
succeeded and the whole bar was read:

```
sh o/bootstrap/cosmic -e 'package.path="o/?.lua;"..package.path; assert(require("_work.gitboard").main("help","bar")==0)'
```

The provided runtime hash matches bin/cosmic.pin:
b4bb8bde84fc54c4298e4d63d949a1af071d2ff5a2e1ba095fa70d9e342ee434.
Use it via `sh o/bootstrap/cosmic` on this host.

## Change

Make a successful worktree verdict honestly establish these bounded facts:
the new checkout exists at the requested exact commit, Git can resolve its
author and committer identities, and every bootstrap subprocess that this
command actually ran exited successfully. This is not a guarantee that
repository-specific build artifacts are complete or validated.

1. In `_work/gitworktree.tl`, make private run_step return explicit
   success/failure plus a diagnostic. Both quiet and verbose paths must
   inspect child.run's result. A nil result is failure with its spawn error;
   a non-ok result is failure with the command and exit code. Preserve
   successful quiet summary filtering, successful verbose inherited streams,
   and full captured stdout/stderr on quiet failure. Do not print resolved
   Git identity values.

   Thread failure through bootstrap and bootstrap_and_refs. On bootstrap
   failure do not copy prepared --ref values and do not emit a positive
   final verdict. Private signatures may change; the public cmd_worktree
   and default_base signatures remain unchanged.

2. Add one small private effective-identity check in that same file.
   Run argv {"git", "var", "GIT_AUTHOR_IDENT"} followed by
   {"git", "var", "GIT_COMMITTER_IDENT"} with cwd set to the checked path.
   Success means both commands return a non-nil successful result.
   Use Git's effective configuration/environment behavior unchanged: global
   identity, inherited repository-local identity, and intentional environment
   overrides are valid. Do not parse names/emails or require new board fields.

   After existing claim, repository, collision, and exact input-commit checks,
   but before git worktree add, apply this check to the resolved product
   checkout. Failure must return nonzero before creating a worktree or branch.
   The existing parent-directory creation may remain where it is; do not
   reorder established authority/collision refusals to implement this check.

   Apply the same identity check to the new checkout before bootstrap and
   again before final success. This catches source-only per-worktree overrides
   and changes made by the bootstrap. On failure name the affected path and
   the failed Git variable, include a precise remedy to configure user.name
   and user.email with `git -C PATH config --local KEY VALUE` (or intentional
   Git identity environment overrides), and preserve the underlying spawn/Git
   error. For per-worktree-only identity, the caller may configure that
   checkout's own worktree scope instead. Never mutate config automatically:
   no copy, no guessed identity, no global writes, and no enabling
   extensions.worktreeConfig.

3. After successful git worktree add, verify that the directory exists and
   resolve its HEAD with the existing product_commit helper; it must equal
   the expected full claim-base SHA for builders or handover SHA for reviews.
   Repeat this exact-checkout validation before final success, after bootstrap
   and prepared-ref handling. A successful subprocess status alone is not
   sufficient if the directory/HEAD postcondition fails. This check is
   repository-independent; it must not inspect or invent required build
   artifact paths.

   Any failure after checkout creation (checkout validation, identity,
   bootstrap, or prepared refs) must use a nonzero final verdict containing
   `checkout created at PATH; preparation failed: REASON`.
   Preserve the created path and branch for caller inspection; never delete,
   reset, reuse, or roll them back automatically. Preserve existing board and
   claim facts. No success final line may follow a failure.

4. Make bootstrap status wording honest without changing discovery.
   Continue recognizing bin/cosmic, third_party/lua, and unrecognized trees
   exactly as today, and continue the same argv for a real bootstrap.
   In the two final success formats replace the word "bootstrapped" with
   "bootstrap:"; keep the handle/path/branch or review-commit information.
   Existing successful build and no-action labels remain unchanged.
   With GITBOARD_WORKTREE_BOOTSTRAP=0 return the label
   `cosmic (skipped: GITBOARD_WORKTREE_BOOTSTRAP=0)`; do not run the
   subprocess and do not describe the skipped build as completed.
   The directory/HEAD/identity checks still apply when bootstrap is skipped.

5. Add the focused regressions to the new
   `_work/gitworktree_bootstrap_test.tl`, using existing fixture/claim
   helpers and small local capture/setup helpers, not a new framework.
   Exercise public cmd_worktree against isolated real Git product/board
   fixtures. Use committed shell-script bin/cosmic stubs, not the actual
   bootstrap wrapper or a network download. Restore every print/env/child.run
   mock with pcall even if an assertion throws.

   Cover:
   - quiet and verbose bootstrap exit failure, and quiet and verbose spawn
     failure; failure names the created path, returns nonzero, retains the
     actual checkout/branch, and does not emit a successful final verdict or
     copy a supplied prepared ref afterward. Quiet failure retains its
     stdout/stderr diagnostics; verbose retains inherited streams.
   - both builder and review failure propagation, and success at their exact
     respective claim-base/handover heads; use a small case table where useful.
   - false success from git worktree add (inject an ok result without creating
     its path) is refused; a bootstrap stub that moves HEAD to another local
     commit is refused by the final exact-HEAD check.
   - explicit shared repository-local user.name/email are usable in the new
     checkout, and source config bytes are unchanged by the command.
   - absent author identity refuses before branch/worktree creation; a valid
     author override with unusable committer identity also refuses, proving
     both Git variables are checked. Test source-only worktree-scope identity:
     source preflight passes but the created checkout lacks a usable identity,
     so post-create validation fails and names its preserved path.
     Isolate global/system config and clear/restore identity environment
     overrides in these fixtures; set user.useConfigOnly where needed to
     prohibit host-dependent automatic identity guesses.
   - explicit bootstrap skipping performs no bootstrap process, labels it
     skipped, and still validates checkout/identity; zero-exit bootstrap,
     unrecognized trees, and cosmopolitan no-action cases remain valid.
   No artifact-existence, cache-reuse, digest, runtime-capability, or network-
   disabled acceptance test belongs to this narrowed item.

6. Update only necessary old test assumptions:
   - In `_work/gitworktree_test.tl`, remove exactly the two measured unused
     sibling-discovery helpers and their immediately associated comment
     blocks. Keep every live test and helper. Configure explicit local
     fixture user.name/email on the checkout returned by make_checkout and
     on the separately constructed master checkout. Change the one skipped-
     bootstrap output assertion to require
     `bootstrap: cosmic (skipped: GITBOARD_WORKTREE_BOOTSTRAP=0)`.
   - In `_work/gitworktree_review_test.tl`, configure explicit local fixture
     identity for the checkout returned by make_pr_checkout and the separate
     checkout constructed in make_loud_pr_checkout. Preserve all review
     authority, exact-head, repeat-refusal, and verbosity assertions.
   These setup changes avoid relying on a developer's global Git identity.

7. Exact source/test scope: `_work/gitworktree.tl`,
   `_work/gitworktree_test.tl`, `_work/gitworktree_review_test.tl`,
   and the new `_work/gitworktree_bootstrap_test.tl`.
   Keep every file <=500 lines. The existing production file has 140 lines
   of headroom; keep helpers small, with no general resolver or public API.
   No new production module, cast, nullable-return public signature, CLI flag,
   credential handling, or board-schema change is needed.

   The only potentially affected baseline row is
   `["_work/gitworktree.tl"]`, currently 79/95, measured with
   `rg -n -F '["_work/gitworktree.tl"]' .cosmic-coverage`.
   If a gate requires a row update, use measured coverage for that row only;
   do not lower coverage of retained behavior or regenerate the full floor.

8. Run scoped type/format/lint checks and all three affected test files.
   Run coverage after the final test edit, then full CI.
   Commit the real implementation before mutations. Independently force a
   failed bootstrap to report success, and bypass the effective-identity
   refusal; each must fail its new focused regression. Also bypass the final
   exact-HEAD check and prove the HEAD-changing bootstrap fixture catches it.
   Restore exactly and rerun the focused tests. Do not claim these mutations
   prove artifact or cache validation.

## Deferred prerequisites

The caller should retain cache-first/digest/runtime work behind AP77_4XCs /
oJ31_ppvR, not infer it complete when this narrower fix lands. Those items
must first provide a named repository-mechanics descriptor API with supported
repository kinds, required artifact paths and capability probes, the authority
of target-checkout pins, raw-versus-assimilated runtime verification, optional
dependency-cache verification, and host invocation selection. This item does
not define that API, mutate those board items, or consume a guessed interface.
The related HNez_qkM2 bootstrap-stamp work also remains separate.
The roughly 40-second network retry remains possible; this item makes its
failure honest, not faster.

## Non-goals

No cache copying, acquisition, digest/stamp changes, runtime/APE assimilation
selection, artifact validation, new network behavior, or repository discovery.
No claim-authority, branch naming, checkout target, prepared-ref source
resolution, credential, provider, or board-state changes.
No automated Git identity/configuration writes, no requirement for local-only
identity when Git's effective identity is usable, and no guarantee that hooks,
signing, or every future commit operation will succeed.
No automatic cleanup of failed checkouts. No unrelated test cleanup beyond
the two specifically measured unused helpers. No other source/baseline edits.

## Access

cosmic-lua/work, read and write on the claimed branch.
Resolved product checkouts are caller-owned inputs: ordinary worktree creation
is allowed, but their source files and Git configuration are not rewritten.
Tests may create and configure their own isolated fixture repositories.
