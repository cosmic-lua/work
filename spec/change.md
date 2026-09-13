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
