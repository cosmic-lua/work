## Change

Depends on the sibling item that teaches `_docs/derive.tl`,
`_build/docs_test.tl` and `skills/decide/SKILL.md` to read a handle —
this one migrates what exists and removes the old form.

The surface, measured:

```
$ ls docs/decisions/d*.md | wc -l
48
$ grep -rEoh '\bD[0-9]{1,2}\b' --include='*.md' --include='*.tl' . \
    | grep -v '^\./o/' | wc -l
480
$ grep -rlE '\bD[0-9]{1,2}\b' --include='*.md' --include='*.tl' . \
    | grep -v '/o/' | wc -l
94
```

480 references in 94 files, and 48 records to rename.

1. Mint one KSUID per existing record, ordered so the minted ids sort in
   the records' own chronological order — a record's id must not imply it
   predates one written before it. Each record's `- **date:**` bullet is
   the ordering key.
2. `git mv` each `docs/decisions/d<NN>-<slug>.md` to
   `docs/decisions/<handle>-<slug>.md`, keeping the slug byte-identical,
   and rewrite its H1 from `# D<n> — <title>` to `# <handle> — <title>`.
3. Rewrite every reference: the markdown links between records
   (`[D45](d45-...md)`), the `superseded by D<n>` and
   `amended ... (... — D<n>)` status lines, and the bare `D<n>` spans in
   prose across `AGENTS.md`, `docs/**`, `skills/**` and the `.tl` doc
   comments that cite one. The pattern is `\bD[0-9]{1,2}\b` plus the
   `d<NN>-` filename form; both are mechanical, and the 94-file list
   above is the work.
4. Regenerate `docs/decisions/README.md` with `bin/cosmic _docs/derive.tl`
   and leave the surrounding prose alone — it is prose.
5. Remove `D<n>` parsing from `_docs/derive.tl` and its cases from
   `_build/docs_test.tl`, since no record carries the form any more.
   A record that still does is then a gate failure, which is the point.

## Non-goals

Changing any record's content, claim, status value, slug or `date`
bullet. This moves identity and nothing else; a record whose body needed
correcting is a separate change.

Introducing a redirect or alias table from old numbers to handles. The
references are all in-tree and all rewritten here; an alias would be a
second identity to keep in step.

External links that name a record by number — a merged PR body, an issue
comment. They are history and are not rewritten.
