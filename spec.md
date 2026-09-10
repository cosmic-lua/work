## Change

Add `cosmic --rewrite PATTERN REPL --preview PATH...` as a non-writing
execution of the same per-file plan used by `--apply`. Base this change on
`34620a7f668117004a5c177b8dbe2e4c6eee5a73`. Keep
`cosmic --rewrite PATTERN PATH...` byte-for-byte equivalent to `--find`,
including its exit status. Explicit preview and apply each require a replacement
and at least one path; `.` selects the current project. Empty REPL is a real
argument and retains statement-deletion behavior.

Implement these invariants and their distinguishing tests together:

| Invariant | Permanent test fixture/assertion | Mutation it must reject |
| --- | --- | --- |
| Preview is an explicit mode | Legacy find/rewrite streams and status equal; preview before/after rewrite; two paths retained; empty REPL retained | Delegate preview to find; make preview consume a path; drop a positional |
| A preview invocation cannot dispatch a writer | Preview alone, both modes, preview with fix/format/compile/embed/extract/make/recipe/execute or another command fail before dispatch; all fixture bytes/mtimes unchanged | Let main's earlier fix branch win; let apply override preview |
| Both modes use one plan | Preview two files with captures, decode predicted code, apply identical bytes and compare every output byte; assert original accepted-site positions | Reconstruct replacement text in CLI; write original/template/unformatted code |
| Refusals remain partial | One clean and one refused hit in the SAME file and also in separate files; preview/apply positions and counts agree; allowed edit lands, comment survives | Abort whole file/run on one refusal; count refused hits as proposed; suppress refusal |
| Preview never opens a source for writing | Backdate each selected file, snapshot bytes plus stat mtime secs/nsecs, run preview, compare all snapshots on success/no-op/refusal/error | Write predicted bytes; rewrite original bytes; touch no-op/refused files |
| Later failure does not weaken preview | Sorted a.tl succeeds, z.tl fails source parse; separately a valid template succeeds in a.tl but fails after substitution in z.tl; preview changes neither, apply still changes a.tl and leaves z.tl | Write early preview file; introduce all-files transaction; return 0 after later failure |
| Replacement is validated | `(` fails even with no hits; `$CMD` replacing a bare call fails after substitution; valid expression, multiple statements, whitespace/comment-only and empty templates are accepted syntactically | Search-only validation; validate only template; reject empty templates |
| Selection is shared | `.` selects executable a.tl and long-string-only s.tl but excludes o/x.tl, testdata/x.tl and noncheckable a.lua; explicit excluded-only selection fails | Walk files separately; count matching text inside strings |
| Counts describe actual planning | Clean, zero-hit, identity replacement, all-refused and file-failure records assert all counts, changed flag, and exact predicted bytes | Compute proposed from all matches on a failed file; hide formatter-only changes |
| Error paths are honest | Controlled in-process read failure and apply write failure report their path, continue later files, and exit 2; preview writer stub must never be called | Swallow fs.read/fs.write error; claim a failed write was applied |

Wire the flag in `_cli/args.tl`, `_cli/parse.tl`, and
`cmd/cosmic/main.tl`. Measured locations (`rg -n 'rewrite|rewrite_apply'
_cli/args.tl _cli/parse.tl cmd/cosmic/main.tl`) include
`_cli/args.tl:41: {long = "rewrite", arg = "PATTERN",`,
`_cli/args.tl:43: {long = "apply", help = ...}`, the Options fields at
`_cli/parse.tl:44-46`, the greedy flags at `:107-108`, and
`cmd/cosmic/main.tl:120: return require("_cli.rewrite").run(...)`.
Declare preview as a bare boolean just like apply, include it in greedy
parsing, and preserve the single positional list. Reject preview without
rewrite, with apply, or with another command flag before startup/command
dispatch can run that command. Leave generic unknown-option/missing-flag-value
errors at the existing CLI status 1.
Allow ordinary help/version requests and non-command parser modifiers; command
conflicts, including `--find`, are errors rather than precedence rules.
Do NOT widen the pinned `_cli.parse.Options` record: the conservative cold-build
overlay uses its shipped shape. Add `_cli/rewrite_mode.tl`, a small typed module
record with `preview: boolean` and `error: string` (nil when absent). After
successful flag parsing, ONLY when rewrite or preview was given, lazily require
this module and reset/populate both fields for this invocation. Set the existing
`opts.rewrite_pattern` to the pattern or `""` for standalone preview (whose
mode.error explains that rewrite is required), and keep `rewrite_paths` populated.
In main, only when `opts.rewrite_pattern` is present, read this module immediately
after generic parse errors, return 2 for its mode.error, and retain its preview
boolean for the later rewrite dispatch. No new module loads on ordinary --make;
do not add it to `_build/make_boundary.tl`. This keeps Options and fresh make's
loaded-module boundary unchanged. Add repeated in-process parse tests proving
that preview/error state resets on the next rewrite invocation.
Append an optional preview boolean to `_cli.rewrite.run` so its existing
three-argument in-process caller remains valid. A final `rg` sweep for
`rewrite_mod.run|require\("_cli.rewrite"\)` must still cover both callers
(base: `_cli/rewrite_test.tl:142` and `cmd/cosmic/main.tl:120`).

In `_cli/rewrite.tl`, replace the write-owning `fix_one` with a shared per-file
planner and a final conditional commit. The measured declarations are
`:35: local function fix_one(pattern: Node, replacement: string, path: string)`
and `:69: local function run(pattern_src: string, paths: {string}, apply: boolean)`.
Find-only remains an early delegation to `find.run`. For preview/apply compile
the pattern once, validate the template once, then select files once through
the unchanged `find.files_for` (`_cli/find.tl:40`). Validate a template by
desugaring it with `ast.desugar`, parsing it as a complete chunk, then trying
`return ` plus the desugared text if chunk parsing failed. Accept an empty
chunk (including whitespace/comments); do not use a nonnil first AST node as
the validity test. Diagnostics identify it as a replacement. This is syntax
preflight, not capture/type/effect analysis; per-file `ast.rewrite` still
validates the actual substituted and formatted result.

The planner reads source, parses/counts original matches (retain this existing
counting step so a failed substitution still has its known match count), then
calls `ast.rewrite` exactly once. Return one concrete internal record carrying
source, match count, result or diagnostic. Preserve read errors. It performs
no writes and takes no preview/apply parameter. Process selected files in their
existing order, report the plan, and only then let apply call
`fs.write(path, result.code)`. Continue to later files after per-file errors.
Do not preplan the whole project before applying: partial application remains.
Apply retains its current formatter behavior, including writing successful
results with no accepted sites or unchanged bytes. Preview has no write path,
including restoration writes, temp replacements, or timestamp updates.

In `cosmic/ast/rewrite.tl`, add `edits: {Hit}` to `RewriteResult` at line 44.
Record the existing accepted splice branch's original Hit values, in ascending
source order, and return them alongside the existing code/refused fields at
line 326. The reverse splice loop is at line 301. Do not recompute acceptance
from text, duplicate the comment rule, or change matching, splicing, deletion,
formatting, or the existing nil/error contract. Existing Refusal nodes and
comments remain the source of refusal diagnostics; the parent module's type
alias already exports RewriteResult. Metadata is present only for a successful
whole-file result: a failed reparse has no applicable edits, and its file-level
error replaces any tentative site decisions. Keep this boundary explicit in
the report. Add AST tests that locate accepted sites in original source order,
omit refused sites, retain deletion edits, and preserve result.code exactly.

Preview stdout contains one compact JSON object per selected file in selection
order, followed by exactly one summary line. Use `cosmic.json` with its default
sorted keys and `json.array` for empty arrays, and handle encoding errors.
A successful record has exactly these keys:

```json
{"changed":true,"code":"assert(os.execute(cmd))\n","kind":"rewrite-plan","matches":1,"path":"a.tl","proposed":[{"column":1,"line":1}],"refused":[]}
```

`code` is the ENTIRE final formatted file as a JSON string: decoding it yields
the exact bytes apply will write. This is replacement content, including all
formatter changes, not just the uninstantiated template. `changed` compares
these bytes with source. Proposed entries locate accepted rewrite sites using
original 1-based line/column, not output coordinates. Each refused entry is
`{"column":C,"comments":K,"line":L}` in original source order. Sort the
report's refusal array without changing the library's existing refusal order.
A failed record is `{"kind":"rewrite-error","matches":M,"message":"...",
"path":"z.tl"}`: M is zero if read/source parsing failed, otherwise the
known original match count; it has no code/proposed/refused fields. Retain
path-qualified stderr diagnostics for file failures and the existing
`rewrite: refused PATH:LINE:COL: would drop K comment(s)` diagnostics in both
modes. Global argument/pattern/template/selection errors print the existing
`rewrite: refused: ...` form and no per-file records or success summary.

The preview summary is exactly:
`rewrite: preview: M match(es), E proposed, R refused, F failed in N file(s)`.
M totals matches known from all selected files, E counts accepted sites from
successful plans, R counts their refused sites, F counts failed files, and N
counts selected files. A file with a failed substitution contributes its known
M but zero E/R, so M need not equal E+R. Identity substitutions still count as
accepted sites, preserving apply's existing site-count semantics; changed=false
distinguishes them. Formatter-only changes have E=0 but changed=true and full
predicted code. Never use `applied` in a preview verdict.

Keep apply's existing summary spelling
`rewrite: A applied, R refused in N file(s)` and stderr refusal spelling;
apply need not print the preview JSON. A counts edits only after successful
writes. Both modes return 2 for rewrite-specific invalid input or any file
read/source parse/substitution/format/report failure (also write failure in
apply), with highest precedence. Otherwise return 1 if any site was refused
or E=0 (A=0 for apply), else 0. Thus clean=0, no accepted sites=1, partial/all
refusal=1, invalid/error=2; counts distinguish no-op from refusal. Explicitly
correct the old apply behavior that could return 0 despite a later bad file,
or return 1 for an invalid splice. This changes error reporting, not partial
application: successful files/sites are still committed when others fail.

Extend `_cli/rewrite_test.tl` with the CLI matrix above, and adjust the existing
invalid-replacement tests' expected status to 2. Do not preserve their misleading
old statuses. Keep new tests in that file while it remains below 500 lines;
put overflow only in `_cli/rewrite_preview_test.tl` as runner-enrolled tests.
Use fixture-local files and cosmic.fs/stat/set_times/child; backdate to a whole
second and compare the observed pre/post secs AND nsecs, requiring no sleep or
nanosecond-timestamp capability declaration. Every preview case compares all
source files, including excluded files. Pair the later-substitution fixture
`a.tl: os.execute(f())` and `z.tl: os.execute(cmd)` with replacement `$CMD`.
Have a controlled in-process fs.write stub reject any preview call and a
separate apply write-failure test; restore overrides even if assertions fail.
Do not broaden fs permissions or depend on root-sensitive chmod behavior.

Update `_cli/args.tl` help, `sys/help.md:31-32`, and add a Structural rewrite
section in `docs/guides/formatting.md` (82 lines at the base). Show capturing
`cosmic --rewrite 'os.execute($CMD)' 'assert(os.execute($CMD))' --preview .`
with stdout/stderr redirected and the exit status saved immediately, explain
the JSON records/counts/statuses and formatter-only changes, then show the
matching apply invocation after evidence review. State syntax validation does
not prove semantic correctness or write permission, partial apply is retained,
and preview evidence must be refreshed after source changes. Update
`cosmic/ast/init_example.tl`'s Example_rewrite to show result.edits positions
alongside result.code. This is the runnable non-writing API example.

No new casts or nil-under-non-nil return signatures are needed: use the existing
Hit/RewriteResult types and an internal nonfallible plan record whose fields
carry failure. Therefore no casts/nil-return baseline additions are expected.
The new rewrite_mode module enrolls by position and adds no baseline row;
its conditional import must leave the make-boundary ratchet unchanged.
Tests/examples enroll by filename/function and need no registry rows; if the
overflow test reads help/docs from disk, add exact `--- reads:` headers.

Focused verification after building the edited dispatcher:
`bin/cosmic --make test _cli/rewrite_test.tl cosmic/ast/rewrite_test.tl
_cli/args_test.tl _cli/find_test.tl` (include the overflow test if created),
then `bin/cosmic --make example cosmic/ast/init_example.tl`. The permanent
tests must kill the matrix mutations, especially write-in-preview, swallowed
later failure, earlier-writer dispatch, and bypassed replacement validation.
Run the repository gate `bin/cosmic --make ci` through its `ci: PASS` verdict;
use its cold-build and `_build/make_boundary_test.tl` checks to enforce the
unchanged pinned parser and fresh-make boundaries.
Do not invent a second per-item acceptance gate or require this unavailable
preview command as implementation preflight. Once implemented, capture its
real evidence before any separately authorized rewrite sweep.

## Evidence

At refinement, `git rev-parse HEAD` printed the base above and
`git status --short` was empty. `wc -l` measured: `_cli/args.tl` 174,
`_cli/parse.tl` 326, `cmd/cosmic/main.tl` 244, `_cli/rewrite.tl` 116,
`_cli/rewrite_test.tl` 225, `cosmic/ast/rewrite.tl` 347,
`cosmic/ast/rewrite_test.tl` 113, `cosmic/ast/init_example.tl` 68,
`sys/help.md` 89, `docs/guides/formatting.md` 82. All have headroom;
rewrite_mode plus the possible overflow test are the new source files. This is one feature,
not a structural replacement sweep with an N-site pattern count.

Measured with `sh bin/cosmic /tmp/oWct-probe.lua` against the exact checkout;
the scratch probe created independent fixture directories, invoked the built
binary with `/bin/sh` from each fixture, and backdated mtime to 1000000.0:

```text
CASE preview_absent EXIT 1
cosmic-lua: unknown option: --preview (try --help)
CASE legacy_search EXIT 0
a.tl:1:1: os.execute(cmd)
find: 1 hit(s) in 1 file(s)
CASE partial EXIT 1
rewrite: 1 applied, 1 refused in 2 file(s)
rewrite: refused b.tl:1:1: would drop 1 comment(s)
a.tl bytes_unchanged=false mtime_unchanged=false
b.tl bytes_unchanged=true mtime_unchanged=false
CASE later_parse_error EXIT 0
rewrite: 1 applied, 0 refused in 2 file(s)
rewrite: z.tl: z.tl:1:7: expected a local variable definition
CASE later_splice_error EXIT 0
rewrite: 1 applied, 0 refused in 2 file(s)
rewrite: z.tl: z.tl:2:1: error: syntax error, expected '='
a.tl bytes_unchanged=false mtime_unchanged=false
z.tl bytes_unchanged=true mtime_unchanged=true
CASE invalid_splice EXIT 1
rewrite: 0 applied, 0 refused in 1 file(s)
rewrite: a.tl: a.tl:2:1: error: syntax error, expected '='
CASE malformed_no_hits EXIT 1
rewrite: 0 applied, 0 refused in 1 file(s)
a.tl bytes_unchanged=false mtime_unchanged=false
CASE selection EXIT 0
a.tl:1:1: os.execute(cmd)
find: 1 hit(s) in 2 file(s)
```

The malformed-no-hits fixture was `local x=1` with replacement `(`; its
output became `local x = 1`. The selected pair was executable a.tl and s.tl
containing only `local s = [[os.execute(cmd)]]`; o/x.tl and testdata/x.tl
were excluded. Direct ast.rewrite also returned success and formatted bytes
for that malformed/no-hit case, and formatted an all-refused source. These
observations are why preview must report whole-file output and why validation
and failure status are explicit changes. The probe establishes the missing
behavior; it does not claim the unimplemented preview tests already pass.

The pinned-boundary list explicitly includes `_cli.args` and `_cli.parse`
(`_build/make_boundary.tl:5`), and `_build/coldbuild_test.tl:39-42` permits
carrying a widened value in a new module instead of release/pin staging.
`sh bin/cosmic --check types /tmp/oWct-boundary-probe.tl`, whose source reads
`parse.parse_args().rewrite_preview` through a local opts, printed:

```text
/tmp/oWct-boundary-probe.tl:3:12: error: invalid key 'rewrite_preview' in record 'opts' of type Options
```

That measured record incompatibility is why the new mode uses a conditional
module instead of widening Options or weakening the cold-build gate.

## Non-goals

No transactional apply, rollback, automatic application, stale-plan execution,
second matcher/rewrite engine, GitBoard logic, type/data-flow validation,
capture binding redesign, general diff engine, or fixes to unrelated AST
matching/splicing semantics. Preserve current project selection, which selects
checkable `.tl` sources rather than arbitrary supplied files. No additional
decomposition is needed for this single preview mechanism; broader semantic
rewrite guarantees require their own item and are not implied by a clean
syntax preview.
