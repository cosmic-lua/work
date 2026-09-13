Measured 2026-08-19 at `bff1007`: the section spans lines 82–231 (150
lines, 30% of the 500-line file), in four blocks. Per block:

1. **The convention bullets (82–106, 25 lines): keep, tighten.** Almost
   every bullet names its gate already (`--check fmt`, `--check types`,
   `--check lint`); compress wording, keep every rule — this is the
   judgment-and-pointer density the file should converge on.
2. **cosmo vs cosmic (107–129, 23 lines): keep the two rules, cut the
   14-row mapping table** — each row restates what `cosmic --docs
   <module>` serves; replace with one line naming two examples and the
   `--docs` pointer. Reclaims ~12 lines.
3. **Common Patterns (130–144, 15 lines): cut to a pointer.** The
   `is_main` pattern with its code block ships via `--docs
   guide.modules`; one sentence and the pointer replace it. Reclaims
   ~11 lines.
4. **Error Handling Patterns (145–231, 87 lines): the whale.** Its own
   opening sentence says the pattern table and worked snippets ship in
   the binary and the doctrine prose is `docs/stdlib.md`. Keep: the
   three honest-nil shape rules, the four-bullet `rules:` block, the
   two-slot fallible-return rule (one paragraph, it is D20 rule 11),
   and one paragraph of pointers (guide.lint owns casts /
   fallible-returns / find-needle; guide.checking and gotchas own
   narrowing; stdlib.md owns doctrine). Cut: the worked narrowing
   paragraphs, the `check.must`/`is`/cast walkthroughs, and the
   `find`-needle detail — every cut rule is enforced by a lint whose
   full text ships in `--docs guide.lint`. Target ≤ 35 lines; reclaims
   ~52.
5. **The decision record**, via the `decide` skill: docs/decisions/dXX —
   no prose exemption from the per-file cap; per-file means splitting
   is permitted but reclamation lands first; prefer making code
   explicit over describing it. Amend-vs-new per the skill's rule
   (D26's form); cite 3I3mjNFi's owner-direction trail as the origin.

Result: the section lands near 75 lines and AGENTS.md near 375 (after
3I3mjNFi's ~450), roughly 125 lines of headroom — the slack the file
has not had since it hit the cap.

Gate to respect while cutting: `_build/snippets_test.tl` reads
AGENTS.md and checks its code snippets — deleting snippets shrinks its
input legally, but the surviving snippets must still pass it, and
`_docs`'s derive test gates the new decision record's grammar.
