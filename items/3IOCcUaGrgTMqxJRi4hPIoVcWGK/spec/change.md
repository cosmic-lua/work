One new file plus the derived index. No code.

1. **Write `docs/decisions/d29-tests-run-because-defined.md`**, first
   line exactly:

   ```text
   # D29 — a test runs because it is defined, not because its file called it
   ```

   Em dash, lowercase after it, one claim. The four sections in D26's
   order and spelling (`- **date:** 2026-08`, `- **status:** active`,
   then `context`, `decision`, `rejected`, `consequences`), matching
   `d28-shape-combinators.md`'s voice: lowercase, terse, real paths and
   real numbers.

   - **context** — the three mechanisms above, with the measured counts
     (266 files, 2,870 definitions, 2,870 call lines, equal today), and
     the three costs the convention carries: the first failure kills the
     file, so one run reports one defect; a test has no per-test
     identity, so narrowing is by file path only and there is no
     `go test -run` equivalent; and the ceremony is held up by a lint
     rule and a warning that exist only to police it, where the
     forgotten call surfaces as "unused variable" rather than as the
     actual mistake.

   - **decision** — one call with sub-bullets, exactly these four and no
     more:
     - **discovery is by name**, from the compile-time lexer walk
       `call-after-define` already uses: a top-level
       `local function test_*` IS the enrolment, token-exact so a
       fixture quoting `end` in a string cannot confuse it, and source
       order is the run order.
     - **invocation is a toolchain-generated in-chunk tail**, appended
       at the compile/check seam, never written to the tree and never
       seen by the formatter or `fmt` —
       `return require("cosmic.test").main({...})`. In-chunk because
       that is the only place file-local functions are reachable;
       appended because it changes no line number, so a failing test's
       traceback still points at the real source line; and the same
       augmented source goes to the type checker, so the checker checks
       what runs and the uncalled-local warning never fires.
     - **a file is all-or-nothing**: every `test_*` self-called is
       legacy mode and compiles unchanged; none self-called is runner
       mode and gets the tail; MIXED is a lint failure. The mixed case
       is the one shape that must never pass, because its uncalled half
       would silently not run under legacy semantics.
     - **the 0/2/fail exit grammar is unchanged** — 0 all passed, 2
       nothing ran, nonzero otherwise — and `check.needs`/`check.reap`
       keep exiting the process, because a missing fixture invalidates
       the file rather than one test.

   - **rejected** — the section D26 says to write hardest. Five, each
     with the reason it lost, drawn from #1366's decision table:
     - a **registration API** (`test.case(fn)`) — moves the forgettable
       call, does not remove it.
     - **body extraction** the way `Example_*` works — recompiles bodies
       lax and orphans shared helpers; a test file must stay whole-file
       and strictly typed, which is what it has today and what the
       example runner gives up.
     - **tests as globals in a custom `_ENV`** — trades a visible
       generated tail for invisible environment magic and cross-file
       global declarations.
     - **a `t` handle** (`t.Error`, `t.Fatal`) — throwing already IS the
       failure mechanism in Lua, so the reason Go needs one does not
       exist here.
     - **a per-file cliff instead of mode dispatch** — 266 files here
       and every user project's tests cannot migrate in one commit, and
       a half-migrated file must fail rather than half-run.

   - **consequences** — the honest costs alongside the wins. It enables
     continue-past-failure, per-test identity in the `.tests` sidecar,
     and a `--filter` matching the benchmark/example contract. It costs
     a compile seam that injects source the tree never contains, which
     is a new place a bug can hide, and it makes `cosmic/test.tl`
     PUBLIC API (a user project's compiled tests require it at runtime),
     so its signature is frozen by D20's charter once shipped. It
     forbids a half-migrated test file, permanently. And it leaves the
     legacy arm in place until a release has carried the toolchain that
     understands both modes, because a runner-mode file under an old
     cosmic must fail loudly — which it does: the old strict compile
     rejects the uncalled locals before the lint even speaks.
     Revisit if per-test isolation (a temp dir, a process) turns out to
     be needed, since the in-process runner is what forecloses it.

2. **Regenerate the index**: `bin/cosmic _docs/derive.tl`, which rewrites
   the table in `docs/decisions/README.md`. Commit the result. Do not
   hand-edit that table.
