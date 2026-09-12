## Change

A decision record's identity is the next free number, which is a shared
counter with no compare-and-swap. Two sessions writing concurrently both
take it. That happened on 2026-09-12: main merged
`docs/decisions/d46-http-engine-is-a-cosmo-binding.md` in #1840, and a
record written independently about ten minutes later also called itself
D46 and had to be renumbered to D47 before it could land (commit
`cc36e07` on `claude/gitboard-markdown-schema-4s47ke`, subject "Merge
main and renumber: D46 is taken"). No earlier renumbering exists:

```
$ git log --diff-filter=R --name-status --format='%h %s' -- 'docs/decisions/d*.md'
(no output)
```

It is the first collision, not a rare one. Every record the project has
was written in the last two weeks:

```
$ git log --diff-filter=A --since='14 days ago' --name-only --format='' \
    -- 'docs/decisions/d*.md' | grep -c 'd[0-9]'
48
$ ls docs/decisions/d*.md | wc -l
48
```

48 records in 14 days, ~3.4 a day, produced by parallel sessions under
`/work N`. A counter cannot hold under that.

Give a record an identity that needs no coordination: a KSUID, the
scheme the board already uses for items, read by `cosmic.ksuid`. It is
time-ordered, so the index keeps chronological order with no counter —
the one property that makes a KSUID right here and a random id wrong.
A record is cited by its **handle**, the id's last 8 characters with a
divider after the fourth, rendered the way gitboard renders an item
handle.

1. `_docs/derive.tl`: parse `# <handle> — <title>` as well as the
   current `# D<n> — <title>`, and accept `superseded by <handle>`
   alongside `superseded by D<n>` in `is_status`
   (`grep -n 'superseded by D' _docs/derive.tl` → line 58). Order
   records by id, which for a KSUID is chronological; a `D<n>` record
   keeps its number as its sort key so a mixed directory stays ordered.
   Both forms parse until the sweep lands.
2. `_build/docs_test.tl`: the index gate covers a handle-identified
   record and a mixed directory.
3. `skills/decide/SKILL.md`: the form section's H1 grammar, the file
   name, and the mechanics block that says "the next free number" all
   name the handle instead. Minting is `cosmic -e` over `cosmic.ksuid`;
   state the one-liner so a writer does not invent one.
4. `docs/decisions/d26-decision-records.md`: amend it. This changes the
   process that record settles, so it carries an
   `- **amended YYYY-MM (<why>):**` bullet and a status, per the
   amend rule in the skill.

New records get handles from this point. Nothing existing moves here.

## Non-goals

Migrating the 48 existing records or the 480 `D<n>` references across
94 files (`grep -rlE '\bD[0-9]{1,2}\b' --include='*.md' --include='*.tl'`
excluding `o/`) — that is the sibling item, and it is the reason this one
keeps `D<n>` parsing rather than replacing it.

The four-section form, the status vocabulary, and the amend-versus-
supersede rule: unchanged. Only identity moves.

Renaming any record's slug. A handle prefixes the slug; the slug itself
is what it already is.

The board's own item ids, which are already KSUIDs.
