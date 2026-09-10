## Change

At main `65cce9fc0ac678c7653493ae282709ef0b7911d9`, extraction fails on
`cosmic.sqlite.Db.exec`: `cosmic/sqlite/extras.tl:16` declares
`params?: bind_mod.Params`, while `cosmic/sqlite/meta.tl:31` declares
`params?: any`. These are separate private declarations folded into one
public-owner namespace by the existing contract.

Explicitly replace the assembler's “conflicting canonical types are an error”
rule. Every occurrence of a folded key contributes its canonical type bytes to
a set, regardless of source path. Deduplicate identical bytes and sort distinct
values lexicographically. This records declarations observed under that name;
it does not claim they are overloads or semantically equivalent.

Preserve `Surface {entries: {string: string}, modules: {string}}`,
`extract`'s signature, all key construction, ownership, exclusions, scanner
behavior, and atomic scan failures.

Encode each entry as follows:

- One distinct type retains its canonical type bytes exactly.
- Two or more distinct types concatenate the literal prefix `@types ` with
  the compact JSON encoding of the sorted string array using
  `cosmic.json.encode`, for example `@types ["integer","string"]`.
- No source path, line, declaration multiplicity, or insertion order enters
  the value.

The reserved prefix cannot begin a valid scanner-produced Teal type because
`@` is rejected by its lexer. JSON preserves embedded quotes, control
characters, and delimiters without ambiguous concatenation. Propagate any
encoder failure through the existing fallible return. This supersedes only
conflicting-duplicate refusal; malformed sources still fail atomically. Update
the assembler documentation accordingly.

Allow only:

- `_tool/surface.tl`
- `_tool/surface_test.tl`
- `_tool/surface_archive_test.tl`

Keep the entire change at or below 220 changed lines. Every file must remain
below 500 lines. Bounce if another product file or module is needed.

Tests must establish exact sorted encoding for different types; collapse of
identical occurrences even beside a different type; invariance under
source-map insertion order, path order, and moving a declaration between
eligible shards; unchanged singleton bytes; a changed value when one distinct
type is removed but no change when only redundant identical occurrences are
removed; and preserved atomic, path-bearing malformed-input failure.

Use the existing comparator in tests to prove that a distinct-type-set change
is exactly one `retyped` delta and that removing redundant identical
occurrences is no delta.

Add an archive integration test that packages the repository's actual
`cosmic/**/*.tl` sources under `.tl/cosmic/**` with the existing temporary
ZIP fixture helper and successfully calls `surface_of`. Declare
`--- reads: cosmic` so source changes invalidate the test. Assert the SQLite
duplicate retains both exact signatures and the existing identical duplicates
remain singleton values. After building, verify
`surface_of("o/bin/cosmic")` succeeds.

Mutation-test the collection guard by temporarily retaining only the first
distinct type for a key. The exact multi-type assertion in
`_tool/surface_test.tl` must fail; restore exactly and rerun it. Run the
archive test separately and complete the normal gate.

The existing renderer prints the encoded value verbatim. Comparisons remain
byte comparisons, and any distinct-type-set change is conservatively
`retyped`; this change does not interpret compatibility among types.

## Non-goals

No SQLite source renames, signature changes, export-reachability analysis,
alias resolution, semantic equivalence, file-qualified keys, path-dependent
values, scanner changes, new surface kinds, comparator or renderer changes,
CLI activation, archive-reader changes, baseline files, dependency pins, or
network access.

## Starting duplicate audit

Exactly three repeated member keys exist:

- conflicting: `cosmic.sqlite.Db.exec` in extras:16 and meta:31;
- identical: `cosmic.quicksand.CapsModule.capabilities` in box/init:42 and
  box/run:57;
- identical: `cosmic.sandbox.Options.best_effort` in init:74 and unveil:61.

Repeated declaration names are `sqlite.Db`, `sandbox.Options`, and
`quicksand.CapsModule`; the latter also occurs in caps.tl:189 with disjoint
members. No further conflicting member keys were found at the starting commit.
