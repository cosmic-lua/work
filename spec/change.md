Rewrite `docs/design/casts.md` so that it states only what is constant
and cites only what a gate verifies. One file; no `.tl` changes.

1. **Delete the snapshot line** (line 12,
   ``Measured against `d3e59de7` on 2026-08-25.``) and the sentence
   beside it about the counts being a snapshot. This is what turns the
   citation gate on for the file, so it must go first.
2. **Delete all seven per-class tables**, headers and `**total**` rows
   included, and every count in the prose — the opening
   "192 of the 402", the "189 of the 192", the "63 files", and each
   class's stated size. The document makes no numeric claim afterwards.
   **A COMPARATIVE claim is a count.** "the largest live class", "the
   largest single win available anywhere in this document", "worth
   roughly a third of this document" — each ranks classes by how many
   sites they hold today, so each drifts exactly the way a number does
   and no gate can see it. They go with the counts, wherever they
   appear, whether they were already in the document or would be new
   prose. `main` carries three — `:5` ("largest single bucket", inside
   the opening sentence this rule already deletes), `:60` (on
   **Decoded-data shaping**, a class with zero live sites, so that
   claim is not merely undurable but false) and `:264` ("worth roughly
   a third of this document", in `## What no mechanism closes`). PR
   #1402's head `8c0b67a6` cut `:5` and `:264` and kept `:60`, then
   added a new one ("This is the largest live class", on **Binding
   boundary**); both of those go. What survives is
   qualitative: what a class IS, and the mechanism that would retire
   it. Where ordering genuinely matters, say it as a property of the
   MECHANISM ("this class closes in the other repository, so it moves
   as a pin bump"), never as a size.
3. **Keep all seven `###` class headings and their "What closes it"
   prose**, and the `## What no mechanism closes` and
   `## What this is not` sections. That is the durable half: the shape
   of each site and the mechanism that would retire it.
   `docs/decisions/d28-shape-combinators.md:7` cites this document for
   the decoded-data-shaping class, so that heading and its closure
   prose stay even though the class has no live site left. "Keep the
   prose" is subject to rule 2: a kept paragraph still has its
   comparative claims cut, which is what `docs/design/casts.md:60`
   needs. Keeping a class whose live count is zero is right — the
   taxonomy is what a future site is read against — but the document
   must not then rank it above classes that do have sites.
4. **Rewrite `## Method`** to hold the census as the one thing a reader
   runs, and to say that the four fixture-text hits are text, not
   casts:

   ```text
   git ls-files '*.tl' | xargs grep -n -- "-- cast: .*from any"
   ```

5. **Quote every live site in the fenced form**, under the class it
   belongs to, classified with the document's own definitions (the
   `## Classes` preamble's "more specific one takes it" rule decides a
   site two descriptions fit). Each is a `text` fence whose first line
   is the `-- <path>:<line>` comment and whose second is the source
   line verbatim:

   ````text
   ```text
   -- cosmic/errno.tl:52
     return (unix as {string: any})[name] as integer -- cast: dynamic E* lookup, from any
   ```
   ````

   All nine sites listed in Evidence get one. A class with no live site
   keeps its prose and cites nothing.
6. **Keep the two mechanism citations inline**: `cosmic/json.tl:135`
   and `cosmic/json.tl:155` name the `decode_object`/`decode_array`
   declarations rather than cast sites, so they stay backticked inline
   references. Drop the remaining inline citations that illustrate
   closed sites.
