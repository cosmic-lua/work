Produce `docs/design/nil-flow.md`, a new file, modelled section-for-section
on `docs/design/casts.md`: an opening that states the total and why it
matters, a `## Method` naming every command the tables were built from,
`## Classes` with one subsection per sink shape, and a closing section
naming the mechanism that closes each class.

The session builds a THROWAWAY strict checker to produce the census —
it is never committed:

1. `bin/cosmic --make fetch && bin/cosmic --make build` to land the
   pinned `tl` under `o/3p/tl/` and a working `o/bin/cosmic`.
2. Edit `o/3p/tl/tl.lua` in place — build output under `o/`, committed
   by nothing — so the four admitting positions above report an error
   instead of passing. Two hinges in the pinned `tl` 0.24.8 admit the
   union, both located and verified at refinement 2026-08-25 against
   the checker a `--make build` produces:

   - `TypeChecker.subtype_relations` (`o/3p/tl/tl.lua:9620`) declares
     `["nil"]["*"] = compare_true` at `:9622` — nil is a subtype of
     everything, so `integer | nil` satisfies an `integer` sink. The
     union side is `["union"]["*"] = TypeChecker.forall_are_subtype_of`
     at `:9681`, with `["union"]["nominal"]` beside it in the same
     `["union"] = {` block at `:9653`; both need the rule. Reject a
     nil-carrying UNION against a sink that does not itself admit nil,
     while leaving bare `nil` a subtype of everything, or
     `local x: string = nil` and every `x == nil` comparison stop
     compiling.
   - `unite()` (`:9144`) sets `types_seen["nil"] = true` at `:9155`
     before it starts, so uniting a union always drops nil — which is
     what the binary-operator path does to both operands before it
     looks up `binop_types`. Report an operand that carries nil before
     that unite, for the arithmetic, bitwise, concatenation and
     relational operators.

   These line numbers are the pinned `tl` and move if the pin moves;
   `3p/tl/tl_pin.tl` stays at 0.24.8 per `Non-goals`, so they hold for
   this slice.

   Two sink shapes decide whether the total means anything, so
   `## Method` states what the prototype did with each:

   - **A parameter typed `any` admits nil and must NOT be flagged.**
     `errno.format(err: any, prefix?: string): string`
     (`cosmic/errno.tl:127`) is the repo's error-wrapping idiom, called
     202 times across `cosmic/ _cli/ _make/ _tool/ _build/ _docs/`
     (`grep -rn --include='*.tl' -E '\b(errstr|errno\.format)\(' … |
     wc -l`, measured 2026-08-25); flagging `any` would swamp the
     census with one idiom.
   - **`string.format` is not settled by its signature.** tl declares
     it `function(string, any...): string` (`o/3p/tl/tl.tl:348`) AND
     registers it as a special function (`set_special_function(…,
     "string.format")`), so its `%d`/`%s` argument check runs
     independently of the vararg's `any`. Whether a `T | nil` at a `%d`
     is flagged is therefore a prototype decision, not a consequence —
     say which way it went and count it consistently, because
     `_build/size.tl`'s `%d` arguments turn on it. `tl.lua` is the checker that RUNS and the file
   the binary embeds; `o/3p/tl/tl.tl` beside it is the Teal source
   carried for `_types/gentl.tl`, and editing that one alone changes no
   behaviour (measured at pull 2026-08-25: a `tl.tl`-only edit rebuilds
   and the probe still passes). Rebuild with `bin/cosmic --make build`.

   The rebuild has a bootstrap order the spec cannot leave implicit: a
   strict `o/bin/cosmic` CANNOT compile this tree, so the strict binary
   must be built by a lax one. Build once with the pin (`rm -f
   o/bin/cosmic` forces `bin/cosmic` to reach for it), keep that lax
   binary aside, and restore it before each strict rebuild.

   Confirm the prototype works by running
   `TEST_TMPDIR=$T o/bin/cosmic cosmic/teal_narrowing_test.tl`
   directly — `--make test` re-execs into the strict binary and fails
   at the build instead — which must now FAIL on
   `test_nil_union_is_admitted_outside_an_index` and only on it. The
   file calls each test where it defines it, so proving "only on it"
   means neutralising that one call in a scratch COPY and seeing the
   rest pass; never edit the tracked file.
3. Run the strict binary over every tracked source —
   `git ls-files '*.tl' | xargs o/bin/cosmic --check types` — and
   capture the flagged sites to a scratch file outside the tree.
4. Classify every flagged site into disjoint classes by the SHAPE of
   the sink, the way `casts.md` classifies by the shape of the site.
   Start from the four positions the pinned test names and add a class
   whenever a real site fits none of them (a return position, a table
   field, a `for` bound). Each class gets: its count, its file table,
   two or three cited `file:line` examples read and quoted, and the
   mechanism that closes it — a guard the author should have written,
   a signature that should not have returned a union, or a checker
   behaviour that would be wrong to demand.
5. Separate, explicitly, the sites where the union is a LATENT NIL
   (the value really can be nil at runtime) from those where it is a
   declaration that should never have been a union. The second kind is
   fixed by narrowing a signature, not by adding a guard, and the two
   seed different follow-up slices.
6. State the doctrine dividend: which of AGENTS.md's 92 narrowing
   lines, and which sections of `docs/guides/checking.md`, a strict
   mode would retire. Quote the line ranges; do not edit them.
7. State a recommendation on upstream-first: whether this is a
   proposal to teal-language/tl, a sixth carried-patch group, or both,
   with the reasoning that follows from the census — not from taste.
8. **Commit the scan output as `docs/design/nil-flow-sites.tsv`** —
   one flagged site per line, three tab-separated fields: the path,
   the line number, and the class name the document gives it. This is
   the evidence a reviewer checks the document against, and it is what
   the first attempt did not have; it replaces the reviewer's only
   instrument being eight hand-picked quotes. Sort it by path then
   line so a diff against a later re-derivation is readable. Write it
   from the strict binary's output before step 10 deletes the
   prototype — it cannot be reconstructed afterwards.

   The 500-line file cap (`_tool/lint.tl:24`, `DEFAULT_FILE_LINES`)
   applies to any file lint walks, data files included, and the first
   attempt found 359 sites. If the re-derived count exceeds 500, split
   by class into `docs/design/nil-flow-sites-<class>.tsv` and say so in
   `## Method`; never reach for `.cosmicignore` to carry an oversized
   one.
9. **Verify every citation the document makes**, before gating: run the
   `Acceptance` citation check below and fix what it names, and read
   each quoted example against its own class definition — an example
   that carries an `or`, an `and` or any guard cannot illustrate the
   no-guard class. Where an example asserts something about a
   `cosmo.*` binding, read the declaration in
   `o/_types/types_gen/cosmo/*.d.tl` and quote it rather than
   inferring the shape from the call.
10. Fix the "Four edits" word at `3p/tl/tl_patch.tl:18` — the one
   source line this slice changes.
11. Delete the prototype before gating: `bin/cosmic --make clean`, then
   `bin/cosmic --make fetch && bin/cosmic --make build`, so the gate
   below runs against an unmodified pinned `tl`.

Then file the follow-up slices as children of this item's parent,
one per class the census says is worth closing, from the board
worktree: `o/bin/gitboard new "<title>" --parent 3IODJgkO
--spec-file <file>`. Each carries the census's own numbers for its
class. Filing them is what turns 3IODJgkO into a container and is
part of this slice, not a note for later.
