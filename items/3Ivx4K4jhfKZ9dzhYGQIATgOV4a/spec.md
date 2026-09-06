## Evidence

`show` and `find` each accept only ONE effective input per call, with
no batch form, which pushes agent sessions toward shelling out in a
loop around the tool rather than asking it once — the exact anti-
pattern `system`'s hard rules warn against ("ALL work state lives in
items here, moved and read through gitboard only"), just at the
read side rather than the write side. Measured this session, filing
four unrelated items' worth of research:

    $ time bin/gitboard show FsQs_WryR
    real  0m0.126s
    $ time (for id in FsQs_WryR 0E11_GJmv gDNw_5bFk omzs_ww5P 5ass_BX1Y; do
        bin/gitboard show "$id" >/dev/null; done)
    real  0m0.477s

~4x for 5 items, purely from paying gitboard's own fixed per-invocation
cost five times — the same "amortize the fixed cost" finding
`cosmic.ast`'s own spike already made about `bin/cosmic` (`docs/design/
ast-rewrite/README.md`, "Performance notes": batching 50 files 1-process
vs. 50-process measured 2.6x, purely from fixed-cost amortization).
`gitboard`'s fixed cost is a different mechanism (trust-root exec +
git-repository reads against the state clone, not process boot) but
the shape of the problem — and its fix — is identical.

**A second, worse gap: `show` silently accepts and drops extra
positional IDs instead of erroring.** This looks like it might mean
"show both", and it does neither — it silently prints only the first
and says nothing about the rest:

    $ bin/gitboard show FsQs_WryR 0E11_GJmv; echo "exit: $?"
    «FsQs_WryR» cosmic/ast: rewrite/splice with comment-loss refusal...
    [... only FsQs_WryR's fields/spec/history ...]
    gitboard-show: 3IvKkQUb is todo
    exit: 0

No mention of `0E11_GJmv` anywhere in the output, no warning, no
nonzero exit — a session (or a human) passing two ids by hand, on the
reasonable guess that it might work, gets a confidently-printed WRONG
answer instead of a refusal. This is the same failure class cosmic's
own promise #1 ("no silent bugs") names for product code, in the tool
that promise's own workflow runs on.

`find TEXT...` has a related but different shape: multiple words are
already accepted, but they compose into ONE bm25-ranked query
(`_work/cachequery.tl:298-312`'s `cmd_find`), not N independent
searches — `find format ast` does not mean "search for 'format', then
separately search for 'ast'", it means "rank hits by both terms
together". Reasonable as a single-query design, but it means there is
no existing spelling for "run these N independent queries and show me
N result sets" either.

This is adjacent to, but narrower than, the already-filed
`«RSTv_DYmH»` ("no read-only verb lists/filters items by
state+priority — consolidate find/show into a query surface"), which
is about listing/filtering by state and machine-readable section
output. Multi-input batching is a distinct gap from that one and
answerable independently of how that larger redesign resolves — filed
as a sibling under the same container (`«c70t_COiw»`, "the verb
surface refuses cleanly and helps accurately") rather than folded in.

## The question

Two designs, not mutually exclusive:

1. **`show` takes N ids**, prints each item's full report in argument
   order (a clear separator between them), and a positional argument
   that fails to resolve to an item is a per-id error line, not a
   silent drop of the whole extra argument — never today's silent
   "print only the first, say nothing about the rest".
2. **`find` gains a way to run N independent queries in one process**
   — e.g. one query per `--query TEXT` flag (repeatable), each ranked
   and printed under its own heading — leaving bare `find TEXT...`
   exactly as it is today (one combined query) for the common case.

Either way, `show`/`find` with no matching id/no hits for a query
should say so per-input, not silently produce a shorter-than-expected
report with no indication anything was skipped.

## Non-goals

Not deciding the listing/filtering/section-output design space
`«RSTv_DYmH»` already owns — this item is scoped to accepting and
correctly reporting on MULTIPLE explicit inputs per call, independent
of whatever `show`/`find`'s single-input output shape ends up being.
