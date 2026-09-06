## Evidence

`docs/design/casts.md` lines ~56–79 (its "Method"/inventory section) describe the cast-site tracking scheme PR #1770 replaced: "holding the path, the line the `as` token is on", reconcile "re-derives path and line", "a cast whose line text is unchanged keeps its class across a move; an edited cast line asks for its class again", "every row's line against a real cast by the lexer". Since #1770 the tsv's columns are `path\tfn\tn\tcast\tclass`, a site is keyed by `(path, enclosing function, ordinal)`, reconcile never touches git, and an edited cast at the same key KEEPS its class. No gate compares this prose to the tsv's shape (`_build/doc_paths_test.tl`, `_build/snippets_test.tl`, `_build/prose_dupes_test.tl` all checked by the builder), so the doc went stale silently.

## Change

Rewrite the "Method" section of `docs/design/casts.md` so it describes the scheme `_build/cast_sites.tl` now implements: the five-column tsv, the `(path, fn, n)` key, the committed `cast` column as the readable text, what reconcile does on a line shift (nothing), on a cross-function move (a refusal naming both keys), and on an in-place edit (class carried, the diff visible in the `cast` column). Add one gated snippet: a `_build/doc_paths_test.tl`-style check or an inline fenced header row that a test compares against the tsv's actual first line, so the column list cannot drift again.

## Non-goals

No change to `_build/cast_sites.tl`, the tsv, or any classification. No rewrite of the rest of casts.md.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.

## Ready when

`docs/design/casts.md`'s Method section names the five columns and the `(path, fn, n)` key, no sentence describes the `(path, line)` scheme, and a test fails if the tsv's header row and the doc's column list diverge.
