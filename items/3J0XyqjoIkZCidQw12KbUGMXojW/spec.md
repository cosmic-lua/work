## Change

Drop the shrink-only ceiling and the zero-site check from the cast-kind
ratchet — decided in review: the count of sites per kind is not worth
tracking; only whether a cast is classified or justified matters. This
is the prerequisite for the sibling item (consolidating classification
into `--check lint`'s `cast-justify` rule), which cannot run per-file
while a global ceiling/exhaustiveness count still needs a whole-tree
pass.

**`_build/casts_kinds.tl`**: remove the `Kind` record's `sites: integer`
field and its doc comment (`grep -n "sites: integer" _build/casts_kinds.tl`
→ one hit, in the record declaration), then delete every `sites = N,`
line from the `KINDS` table — `grep -c '^\s*sites = ' _build/casts_kinds.tl`
→ 17, one per kind entry (`grep -c '^\s*name = "' _build/casts_kinds.tl`
→ 17, confirming one-per-kind, none missed).

**`_build/casts_test.tl`**: delete `test_no_kind_exceeds_its_committed_ceiling`
(the function reading `c.kind.sites`, currently lines 212-232) and
`test_every_kind_has_at_least_one_site` (currently lines 234-253) in
full — both functions and nothing else. Leave
`test_every_cast_site_matches_exactly_one_kind` (currently lines
187-210) and every function it calls (`scan`, `compile_kinds`,
`is_in_scope`, `kind_matches`, `near_matches`, `matching_kinds`, the
`Site`/`Compiled` records, `ANY_CAST`) untouched — the sibling item
moves that logic into `_cli/lint.tl`; this item only removes the two
ceiling-related tests and the schema field they read.

**`docs/design/casts.md`**: rewrite the Method section's paragraph
that currently reads (lines 33-40):

```text
Three checks run every kind against the walk: every cast matches
exactly one kind (a site matching none names `file:line` and, when
some kind's pattern would have matched outside its own scope, the
kinds it nearly matched; a site matching two names both); no kind
matches more sites than the ceiling committed beside it in
`_build/casts_kinds.tl`, shrunk by hand as sites close; and every
kind still has at least one site — a kind at zero is deleted
outright, heading and all, never kept at zero.
```

to name the one remaining check only (every cast matches exactly one
kind, with the same zero-match/two-match diagnostics), dropping the
ceiling clause and the "kind at zero is deleted" clause entirely —
kinds are no longer deleted by this mechanism when their count
happens to hit zero; a kind's removal, if it ever comes to that, is a
separate editorial decision, not something a test enforces.

Also reword the closing "What this is not" section's sentence (lines
451-458) — "`_build/casts_kinds.tl` is the allowlist that holds each
class's site count down, checked against a fresh walk of the tree by
`_build/casts_test.tl`" — to drop "that holds each class's site count
down" (no count is held down any more); keep the rest of the sentence
(the allowlist is still checked against a fresh walk, until the
sibling item retires `_build/casts_test.tl` in favor of `--check
lint`, which is out of scope here).

Neither touched passage contains a fenced ` ```text ` citation block
(the file's only such blocks are the per-class worked examples under
`### ` headings, lines 66-450, none of which this item edits), so
`--check lint`'s citation rule (`_cli/citations.tl`) has nothing new
to re-verify here.

## Non-goals

Does not change what makes a cast pass or fail: `cast-justify` (the
comment requirement) and `casts_test.tl`'s classification test both
keep running exactly as they do today. Folding them into one `--check
lint` rule, and deleting `_build/casts_test.tl`, is the sibling item.

## Acceptance

`bin/cosmic --make ci` ends `ci: PASS`. `bin/cosmic --make test
_build/casts_test.tl` passes with two fewer test functions and no
`sites` field anywhere in `_build/casts_kinds.tl` (`grep -c sites
_build/casts_kinds.tl` → 0).
