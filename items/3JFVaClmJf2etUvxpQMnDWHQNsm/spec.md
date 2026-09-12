## Evidence

`cast-justify` no longer sees a `-- cast:` justification on a MULTI-LINE
cast, so a cast that was justified correctly is reported as unjustified.

Reproduced by bumping `cosmic-lua/work`'s `bin/cosmic.pin` from
`2026-09-07-2b2002d` to `2026-09-12-526ffa1` and changing nothing else.
Four files that are green on work's `main` under the old pin go red under
the new one: `_work/apiauth_test.tl` (3), `_work/gh_test.tl` (4),
`_work/ghwrite_test.tl` (16), `_work/gitverdict_transport_test.tl` (1) —
24 diagnostics, `ci: FAIL (lint)`.

The two shapes, from one file, under the new pin:

    99:      return nil, why as fetch.Error -- cast: fetch.Error is an opaque string error
    -- NOT flagged: single line, justification trails the `as`

    101:     return {status = reply.status, headers = {}, raw_headers = {},
    102:       body = reply.body, url = url}
    103:     as fetch.Response, nil -- cast: a fabricated response, not a real Fetch return
    -- FLAGGED at line 101, though line 103 carries the justification

The diagnostic anchors at the expression's FIRST line (101).
`style.is_justified(lines, y, "cast")` inspects line `y` and the line
directly above it, so a justification on the line that actually carries
the `as` token — two lines below — is invisible.

The cause is `«#1797»` ("cast-justify: fold cast-kind classification into
`--check lint` per-file"), which moved the check from a lexer-only scan to
`cosmic.ast`. Its own commit message names the change: "checked per file
via `cosmic.ast` rather than the old lexer-only scan". The lexer found the
line bearing the `as`; the AST reports the node's start. The justification
convention the rule documents — "a trailing `-- cast: <reason>` (or one on
the line directly above, when 90 columns will not fit it)" — is stated
relative to the `as`, which is where authors put it and where the old
scanner looked.

None of the flagged files changed: they are byte-identical to work's
`main`, whose CI is green on the old pin. The only variable is the cosmic
version.

The cost is borne downstream and looks like unrelated churn: every project
whose casts span lines must relocate its comments to a line that reads
oddly (above the opening brace of a table constructor, several lines from
the `as`), or lose the rule. Work hit 24 sites in four files from one pin
bump.

## Change

Make `cast-justify` accept a justification where the convention says to
put it: trailing the line carrying the `as` token, as well as the
expression's first line and the line above it. The AST node's extent is
available at the point the diagnostic is built, so the span to search is
the cast's own lines rather than a fixed one-line window.

Keep single-line casts, the allowlist path, and the diagnostic's anchor
line as they are — only which lines are searched for the justification
changes.

Add cases: a multi-line cast justified on its `as` line passes; one with
no justification anywhere still fails; and the existing single-line and
line-above forms keep passing.

## Non-goals

Not reverting `«#1797»` — per-file AST classification is the right
direction and the allowlist behaviour it added is unaffected. Not changing
`_build/casts_kinds.tl`, `assert-justify` or `throw-justify` unless they
share the same helper and the same defect, in which case say so and fix it
once. Not relocating any justification comment in cosmic's own tree to
work around this.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.
