## Evidence

A spec's `## Evidence` section cites file:line locations for the facts it
relies on (per `gitboard help bar`: "measured during refinement and
written into the prose WITH the command that produced it"). When a
sibling item under the same parent lands between refinement and pull,
those line numbers silently go stale — the cited fact is often still
true, but at a different line, costing the puller/reviewer tool calls to
relocate it before they can even start verifying the claim. Three
independent instances this session, each on `cosmic-lua/work`:

1. `rEEV_Vvhk`'s spec (`AP77_4XCs`'s child) cited `_work/gitworktree.tl`'s
   `bootstrap()` as running only `bin/cosmic --make build` ("as today").
   By the time it was pulled, an already-landed unrelated item
   (`d956948d`, verified-runtime bootstrap) had changed that function's
   behavior; the builder had to reconstruct the history via `git log`/
   `git show` (reported in its own friction section) before concluding
   the spec's "as today" line was stale prose, not a real contradiction
   to resolve.
2. `YedR_ZHgk`'s spec quoted `_work/brieftext.tl:54-56` verbatim
   ("if the Change's additions cannot fit under the 500-line cap, STOP
   now"). By pull time the file had grown a split-seam paragraph around
   that sentence; the exact quoted text no longer existed at those
   lines. The builder found the live equivalent by grepping for "500-line
   cap" instead of trusting the citation (reported in its own friction
   section).
3. `3aE2_amFS`'s round-1 reviewer, verifying a byte-identity claim
   against `_work/brieftext_review.tl:113-114`/`131`/`215`, found those
   line numbers no longer matched current file content (an earlier
   sibling item had already shifted them) and had to locate the same
   text by grepping the literal command strings instead — explicitly
   naming this as friction and suggesting specs "quote an anchor string"
   alongside line numbers so a shift doesn't strand the citation.

All three are the same root cause: a line-number citation is exact at
refinement time and never re-validated, while the codebase around it
keeps moving (particularly likely here, since items under one outcome
frequently touch overlapping files in sequence, each landing before the
next is pulled).

## Change

`gitboard help bar`'s guidance on citing evidence (the paragraph
containing "A Change that names a function or a string quotes the
`grep -n` hit that places it") already requires quoting the `grep -n`
hit for a function/string citation — extend this same requirement to
every bare file:line citation of quoted source text in `## Evidence`:
the citation must pair the line number with a short, still-`grep`-able
literal string from that exact line (a distinctive substring of the
quoted text itself is sufficient — no new tooling, no new spec
section). A citation with a number but no anchor string is under the
bar the same way an unmeasured claim already is.

Update the one place this rule is documented (`gitboard help bar`) to
state it applies to file:line citations generally, not only to the
function/string-placement case it currently names, with one worked
example showing a citation before and after (a plain `:54-56` citation
next to a quote, versus the quote plus its own `grep -n` hit).

## Non-goals

Not adding automated staleness detection, not re-validating existing
open items' specs retroactively, not changing the bar's other citation
rules (behavioral claims' command+output requirement, measured-fact
requirements) — only the file:line-citation-of-quoted-text case.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
