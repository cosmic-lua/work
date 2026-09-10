## Evidence

Refined read-only in the claimed cosmic-lua/work checkout at
`1490f2eacbd1bc90fe357238667eb9c72f8ff704`.
`git rev-parse HEAD` printed that SHA; `git status --short` printed nothing.
`rg --files -g AGENTS.md -g SKILL.md -g Makefile -g '*repoprofile*' -g '*mechanic*' -g '*profile*'`
and `rg --files _work | rg 'repoprofile|mechanic|profile'` returned no paths.
This does not establish conventions in another repository.

`wc -l _work/product.tl _work/gitworktree.tl _work/brieftext.tl _work/repository_map.tl _work/doctrine_bar.tl`
printed 33, 398, 401, 81, and 106 respectively. The complete
`_work/doctrine_bar.tl` was read directly; no gitboard command ran.
`rg -n 'local function (default_base|bootstrap)|local function validate|local function resolve' _work/gitworktree.tl _work/repository_map.tl`
located gitworktree default_base:75, bootstrap:161, bootstrap_and_refs:220,
and repository_map validate:17/resolve:49. Reading those functions shows
that existing worktree preparation runs only `bin/cosmic --make build`,
recognizes `third_party/lua` separately, and retains a repo-name base fallback.
This item does not change those callers. Product.tl is constant repository
identity data, not an existing mechanics resolver.

`rg -n -F -e '--make ci' -e '--make build' -e '--make test' -e '--check types' _work/brieftext.tl _work/brieftext_review.tl`
found the current cosmic command prose in brieftext:17,18,80,85,94,99 and
brieftext_review:109,110,127,205. These are downstream sites, not this diff's
change set. The later worktree caller needs kind, bootstrap argv sequences,
and an independent default-base result; the later brief caller needs all
four optional command forms. Neither currently prescribes a resolver API.

The old non-execution premise was reproduced in an isolated temporary
directory `/tmp/oj31-refine.HD09og`, not a product checkout. Its Makefile was:

```make
PARSE := $(shell printf parse > parse-marker)
gate:
	+printf recipe > recipe-marker
```

`/usr/bin/make --version` reported GNU Make 3.81. Through the pinned runtime,
the actual probe was:

```sh
sh o/bootstrap/cosmic -e 'local c=require("cosmic.child"); local fs=require("cosmic.fs"); local p="/tmp/oj31-refine.HD09og"; local r,e=c.run({"/usr/bin/make","-n","-f","Makefile","gate"},{cwd=p}); print("make_exit="..tostring(r and r.code)); print("parse_marker="..tostring(fs.read(fs.join(p,"parse-marker")))); print("recipe_marker="..tostring(fs.read(fs.join(p,"recipe-marker"))))'
```

Output: `make_exit=0`, `parse_marker=parse`, `recipe_marker=recipe`.
Thus neither `-n` recipes nor Makefile parsing is a non-executing discovery
mechanism. No variant of invoking Make is used below.

A second temporary fixture `header.mk` contained the ordinary Make syntax
`.PHONY: bootstrap gate check-file test-file`, then `gate:` and the TAB-prefixed
recipe `@printf gate`. The pinned-runtime child call
`{"/usr/bin/make","-n","-f","header.mk","gate"}` in that temporary directory
printed `literal_header_exit=0` and `literal_header_stdout=printf gate`.
The new advertisement uses existing Make syntax, not a new manifest format.

`git --version` reported 2.50.1 (Apple Git-155). In a separate-purpose Git
fixture initialized in that same temporary directory, child argv
`{"git","symbolic-ref","-q","refs/remotes/origin/HEAD"}` returned exit 1
before the symbolic ref existed. After a fixture-only `git symbolic-ref
refs/remotes/origin/HEAD refs/remotes/origin/feature/integration`, that exact
read returned exit 0 and `refs/remotes/origin/feature/integration\n`.
This is a local cached symbolic ref, not a query to the remote.

The pinned-runtime probe `fs.is_file` on temporary regular, regular-symlink,
dangling-symlink, FIFO and directory markers returned respectively
`true, true, false, false, false`; links were made with `ln -s`, the FIFO
with `mkfifo`, and the directory with `mkdir`, all under that same temp root.

`shasum -a 256 o/bootstrap/cosmic` matched bin/cosmic.pin:
`b4bb8bde84fc54c4298e4d63d949a1af071d2ff5a2e1ba095fa70d9e342ee434`.
Use the verified runtime through `sh o/bootstrap/cosmic` on this host.
The hidden baseline sweep `rg --files --hidden -g '.cosmic-*' -g '*baseline*' -g '*ratchet*'`
found only `.cosmic-coverage`; the exact search for
`["_work/repoprofile.tl"]` in that file returned no row.

## Change

Land one small resolver of local, advertised repository command conventions.
It returns command plans, never executes those plans or proves they work.
No external prerequisite is needed for this foundation; real non-cosmic
repositories and the two caller children adopt its contract separately.

1. Add `_work/repoprofile.tl` and `_work/repoprofile_test.tl` only, plus the
   measured new production coverage row described below. Export this exact
   interface so the subsequent callers share one shape:

   ```text
   Kind = "cosmic" | "make" | "absent"
   Profile = {
     kind: Kind,
     bootstrap: {{string}},
     gate: {string},
     check_file: function(file: string): {string},
     test_file: function(file: string): {string}
   }
   resolve(checkout: string): Profile
   default_base(checkout: string): string
   ```

   Express these using ordinary Teal enum/record declarations and export
   the Kind/Profile types. Empty bootstrap means no advertised step; an
   empty argv means that command is not advertised. File-taking functions
   always exist, returning `{}` when unsupported. Return fresh arrays on
   each resolution/file-command call; mutation of one plan must not change
   another. Preserve a supplied file string as one argv value, without
   shell quoting, tokenization, normalization, expansion, or execution.
   This module uses no board/store/claim state and writes nothing.

2. `resolve` performs only local filesystem inspection. Empty, nonexistent,
   non-directory or unreadable input degrades to an absent profile. Check
   `bin/cosmic` first: if `fs.is_file` reports a regular file, return cosmic,
   regardless of its contents, execute bit, or any Makefile. Match existing
   file-presence convention, not runtime validation. `fs.is_file` follows
   symlinks: links to regular files are accepted for both marker files;
   dangling links, directories, FIFOs/devices/sockets are not marker files.
   Do not recurse or search parents/siblings. No Git probe belongs in
   `resolve`; default-base resolution is independent.

   The cosmic profile is fixed:

   ```text
   bootstrap = {{"bin/cosmic","--make","fetch"},
                {"bin/cosmic","--make","build"}}
   gate = {"bin/cosmic","--make","ci"}
   check_file(file) = {"bin/cosmic","--check","types",file}
   test_file(file) = {"bin/cosmic","--make","test",file}
   ```

3. Otherwise inspect only root `Makefile`, and only if it is a regular file
   under the policy above. Recognize the following deliberately narrow
   declaration convention; do not implement or approximate Make evaluation.

   Read at most 65,537 bytes with one bounded binary `io.open`/`read` and
   close the handle on every read outcome. Only a complete declaration
   ending within the first 65,536 bytes is eligible. LF and CRLF line
   endings are accepted; an EOF-terminated line is accepted only when EOF
   occurs at or before that limit. An incomplete line at the limit, open/
   read/close failure, or NUL before the declaration ends makes this absent.
   Bytes after the declaration are opaque, even when already in the bounded
   read buffer. Large Makefiles are allowed if their declaration fits.

   Scan physical lines from the start. Skip blank lines containing only
   ASCII space/TAB, and comments matching zero or more ASCII space/TAB
   followed by `#`. A skipped comment whose last non-space/TAB byte is
   backslash refuses the whole Make profile: do not misread a continued
   comment as a declaration. Do not join lines. A BOM is not ignored.

   The FIRST remaining physical line must start at column one with the
   exact literal `.PHONY:`, followed by at least one ASCII space/TAB and
   one or more tokens separated by ASCII space/TAB; trailing space/TAB is
   permitted. The entire token allowlist is exactly `bootstrap`, `gate`,
   `check-file`, `test-file`, in any order. A duplicate, unknown token,
   empty token list, inline comment, variable reference, escaped byte,
   continuation, semicolon, prerequisite expression, or any other syntax
   refuses the whole Make profile. A leading indentation before `.PHONY:`
   also refuses it. No partial capability extraction from a malformed line.

   Never scan beyond that first meaningful line to find another candidate.
   Thus declarations inside conditionals, defines, recipes, included files,
   or after assignments are not advertisements for this contract. Do not
   parse those constructs, follow includes, expand variables/functions,
   consult MAKEFILES/MAKEFLAGS, or invoke `make`, a shell, `bin/cosmic`, or
   any repository-provided executable during discovery.

   A valid nonempty declaration returns kind make, advertising exactly its
   named capabilities. Missing capabilities are empty, not errors. Plans:

   ```text
   bootstrap = {{"make","-f","Makefile","bootstrap"}}  # if advertised
   gate = {"make","-f","Makefile","gate"}             # if advertised
   check_file(file) = {"make","-f","Makefile","check-file","FILE="..file}
   test_file(file) = {"make","-f","Makefile","test-file","FILE="..file}
   ```

   The consumer executes plans, if authorized, with cwd equal to the
   supplied checkout. `-f Makefile` selects the file the resolver inspected
   instead of letting `GNUmakefile` or `makefile` precedence select another
   interface. It does NOT freeze that file's bytes, suppress later Make
   evaluation/environment, attest recipes, or authorize execution. A literal
   declaration is an advertisement only, not proof of successful bootstrap,
   target implementation, dependency availability, or artifact readiness.

4. `default_base` independently performs only the local read argv
   `{"git","symbolic-ref","-q","refs/remotes/origin/HEAD"}` with cwd set
   to the supplied checkout. Empty input returns `""` without a subprocess.
   Spawn failure, nonzero exit, or malformed output returns `""`, including
   a non-Git directory or missing cached symbolic ref. On success remove
   exactly one trailing LF and its optional preceding CR, require the exact
   prefix `refs/remotes/origin/` and a nonempty suffix, and reject remaining
   ASCII whitespace/control bytes. Return that suffix unchanged, retaining
   embedded slashes and non-ASCII branch-name bytes. Do not use `--short`,
   guess main/master, inspect the current branch, fetch, query a provider,
   or run `git remote set-head`. This result says what the local symbolic
   ref names; callers retain responsibility for fallback/commit validation.
   Normal filesystem/subprocess failures in either public function must
   return their documented empty outcome, not assert or throw.

5. Put permanent proof in the new test sibling using isolated temporary
   files/repos and existing fixture style; no network or actual repository
   build. Restore print/env/child/fs mocks with pcall even on assertion failure.
   Cover cosmic precedence and exact argv; all four Make capabilities and
   proper subsets; every lexical refusal above; LF/CRLF/EOF, UTF-8 comments,
   the exact prefix boundary and oversized/incomplete prefix; irrelevant
   tail contents; unknown trees and I/O failures; regular symlink markers,
   dangling links and non-regular markers; fresh independent argv arrays.
   Test filenames containing spaces, equals, backslashes and shell-looking
   text are retained as one argument and never evaluated.

   Use a make-kind fixture with a valid declaration followed by BOTH a `$(shell ...)` parse-time
   marker writer and a `+` recipe marker writer, plus an executable marker-
   writing bin/cosmic in a separate cosmic-kind fixture. Assert the respective
   resolved kinds; after resolution all markers must be absent.
   Also instrument `child.run` with a counter and a failing sentinel: every
   `resolve` call must make ZERO subprocess calls, even when child failures
   would be swallowed. An included declaration must not be discovered;
   a competing GNUmakefile must neither be read nor change returned argv.

   Test the default-base helper in real temporary Git repos with absent
   origin/HEAD and with a fixture-created symbolic origin/HEAD naming
   `feature/integration`. No commit, clone or remote is needed. Separately
   assert its exact argv/cwd and empty results for spawn/nonzero/malformed
   responses. It must work independently for cosmic, make and absent kinds.
   The kind resolver must not call this helper implicitly.

   Run scoped types/format/lint and the new test file, then coverage and the
   full `sh o/bootstrap/cosmic --make ci` gate. Add only the measured
   `["_work/repoprofile.tl"]` production row to `.cosmic-coverage`; keep
   existing rows byte-for-byte and never invent test-file rows. Keep both
   new files below 500 lines; do not split/reorganize existing modules.
   Commit the implementation before mutations. Separately add a Make
   subprocess discovery call and change first-meaningful-line refusal into
   scanning onward; each must fail its new regression. Restore exactly and
   rerun the focused test. No baseline reduction may make a mutant green.

## Compatibility and sequencing

This replaces dry-run target probing with a literal advertisement contract.
Ordinary Makefiles without that leading declaration intentionally resolve as
absent; no claim is made that the current cosmopolitan Makefile already
implements it. A follow-on may place this ordinary `.PHONY:` declaration
before assignments/includes and implement the selected targets in that repo.

Before pulling the later worktree/brief integration children, refine their
fixture assumptions to this grammar and their Make argv to `-f Makefile`.
They consume the Profile shape above, including ordered cosmic fetch/build,
optional make bootstrap, file-command functions, and independent default_base.
Existing worktree/bootstrap/base-fallback and legacy brief behavior remain
unchanged until those children land. Do not edit those specs or callers in
this implementation. No data migration is needed: no resolver or stored
profile exists at the measured base, and no board/caller records change.

## Non-goals

No Make dry-run/database/query/evaluation, shell probing, general Make parser,
include discovery, inferred target rules, repository-name dispatch, alternate
manifest/schema, new CLI verb/flag, automatic execution, or discovery writes.
No caller integration, actual cosmopolitan Makefile changes, receipt changes,
claim/base-authority changes, transport/provider/credential access, or cache
changes. No runtime/launcher/digest/capability attestation, artifact audit,
executable-bit guarantee, successful-command guarantee, or protection against
a repository changing after discovery. The command plan is not authorization.

## Access

cosmic-lua/work only: the two new resolver/test files and its measured new
coverage row. Tests may create their own isolated temporary fixtures. No
other repository, product source/config mutation by the resolver, or board
mutation is permitted.
