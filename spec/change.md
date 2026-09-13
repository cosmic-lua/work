Ten files: one new record, two derived/doc updates, and trailing
justification comments at 19 sites in 7 modules. **No executable line
changes anywhere** — every site keeps its exact behavior, message, and
error level; the diff outside `docs/` and `AGENTS.md` is comments only.

### `docs/decisions/d30-*.md` — new record

Written by the `decide` skill's form (H1 `# D30 — <claim, lowercase>`,
then date/status/context/decision/rejected/consequences). The decision,
stated as a rule with three sub-bullets: **a `cosmic.*` module may
throw or exit only where no caller could receive the value**, which is
exactly three shapes —

1. a Lua protocol whose error channel is the throw (a package
   searcher/loader, a `coroutine.wrap` re-raise);
2. a process boundary: a post-`fork` child that cannot return, or an
   entry helper (`cosmic.main`) whose caller is the OS;
3. an infallible-by-type function whose typed contract was violated
   through a cast, or whose binding failure is unreachable for the
   arguments it passes — `cosmic.hash`'s shape, the per-module record
   D23's amendment demanded.

Each site carries a trailing justification: `-- throws: <why>` on an
`error(` line, `-- exits: <why>` on an `os.exit(` line, or either as a
comment on the line directly above when the 90-column width won't fit
it — the same grammar contract as `-- cast:` (AGENTS.md) and
`-- assert:` (D23). `cosmic/check.tl` and `cosmic/rand.tl` carry no
comments: their exemptions are module-level, recorded in D23 and D22.

Rejected alternatives to write hardest: returning `nil, string` from a
loader (breaks `require`'s found-but-broken channel), a module
allowlist without per-site comments (D23's amendment already rejected
the seat-on-a-list shape for `-- assert:`), and folding this into a
second D23 amendment (D23 is check's record; these shapes are not
about check).

Cite paths and functions in prose; do NOT quote source lines in
citation-headed code blocks (`-- file.tl:NNN`) — the doc-citation lint
verifies those against the tree and every annotated line moves in this
same diff.

### The 19 site comments

Add the `-- throws:`/`-- exits:` comment at every census site, with
the shape's reason in that site's own words (e.g. searcher:
`-- throws: package-searcher protocol; require reports load failures by raising`;
child: `-- exits: forked child, exec failed; error already on the parent's pipe`;
hash: `-- throws: Algo contract violated through a cast; digest is infallible by type`;
init: `-- exits: entry helper; the caller is the OS`). Trailing where
the line stays ≤90 columns, line-above otherwise.
`cosmic/quicksand/box/run.tl:287`'s existing `-- unreachable` trailing
comment is subsumed into its `-- exits:` comment rather than kept
beside it.

### `AGENTS.md` — one bullet

The "never throw from library code" bullet (line 237) extends its
parenthetical: the three D23 shapes stay, and the sentence gains "and
D30's three: a protocol whose error channel is the throw, a process
boundary with no caller, and an infallible-by-type contract violation
— each site carrying a trailing `-- throws:`/`-- exits:` reason".
Keep it to the one bullet; no other AGENTS.md prose moves.

### `docs/decisions/README.md` — regenerate

`bin/cosmic _docs/derive.tl` rewrites the derived index table with
D30's row; commit the result. Never hand-edit it. If any other ratchet
complains, run exactly the regen command its failure message prints
and commit the result.
