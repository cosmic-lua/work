## Evidence

`gitboard new` warns about a near-duplicate through `_work/find.tl`'s
`similar`: an FTS5 `bm25()` ratio over TITLES only, threshold
`SIMILAR_RATIO = 0.5`. Measured against the production board (914 items, the
procedure in find.tl's header, 2026-09-04): four known duplicate/overlap
pairs score 1.00, 0.62, 0.40 and 0.27 against their true match; twenty
unrelated titles score 0.21–0.91 (mean 0.57) against their own closest
other title. The spreads overlap over their entire range, so no threshold on
this signal separates a duplicate from a topically related item — the
warning today is noise for roughly as many `new` calls as it is signal.
Two facts bound the fix: `--make ci` runs inside a loopback-only network
namespace, so nothing at test time may call out; and the cache
(`o/board.db`) is derived and rebuildable from git alone, so anything stored
there must be recomputable offline or degrade cleanly when absent.

## Change

Research with one shippable outcome: find a similarity signal that
separates the known pairs from the controls with margin, and either ship it
as `similar`'s engine or record why none is available offline and what a
remote embedding stage would cost. Deliverable: a `--result` handover with
the measurements below and the follow-up item(s).

1. Fixture. Reproduce find.tl's measurement and record the ids of the four
   pairs and the twenty controls in `_work/testdata/similar_pairs.tl` (a
   literal table, read by `cosmic.literal`), so every later signal is scored
   on the same set and a test can hold the margin.
2. Signal A, offline: TF-IDF over title AND spec (the header's measurement
   was title-only), cosine similarity, vectors built from the `search` FTS
   table's tokens (`porter unicode61`, same tokenizer) so nothing new is
   parsed. Score the fixture; paste best-match and closest-control numbers.
3. Signal B, offline: hashed character 3-gram vectors of the title (a fixed
   `dim` of 512, FNV-hashed), cosine. Same scoring.
4. Decision rule, stated before measuring: a signal ships if every pair's
   true-match score exceeds every control's closest-other score by at least
   0.10. If A or B passes, the follow-up is one item: `similar` computes
   that signal over the cache connection, `SIMILAR_RATIO` and the bm25 path
   go, and `_work/find_test.tl` asserts the margin on the fixture. Vectors
   are not stored: 914 items × 512 floats is recomputed in well under the
   `new` verb's current 0.2 s.
5. If neither passes: record the gap and spec the remote stage as a
   follow-up with these decisions already made — vectors live in the cache
   as `vectors(id TEXT PRIMARY KEY REFERENCES items(id) ON DELETE CASCADE,
   model TEXT NOT NULL, content_sha TEXT NOT NULL, vec BLOB NOT NULL)
   STRICT, WITHOUT ROWID`, keyed by the sha of title+spec so a rebuild
   re-embeds only what changed; brute-force cosine in Teal (no sqlite-vec —
   the pinned cosmic's sqlite is statically linked, and
   `grep -n load_extension o/_types/types_gen/cosmo/lsqlite3.d.tl` says
   whether an extension could even load); `similar` falls back to the
   offline signal when a row is missing, so `--make ci` and a fenced
   session never need the network; the API and its key come from the
   environment, never the tree.

## Non-goals

Semantic search for `find` (lexical FTS stays the `find` engine); storing
anything embedding-derived in the truth store (`refs/heads/items/*`);
auto-merging or auto-closing suspected duplicates — `new` warns, a person
decides.

## Result (measured 2026-09-05)

Corpus: `store.list`/`store.read_specs` against the live production
board (`cosmic-lua/work`, `refs/heads/items` + `refs/heads/ended`, same
load path `_work.cache.rebuild` uses) — 959 items today (914 on
2026-09-04; the count moved, the shape of the finding did not).

**Fixture.** The original 2026-09-04 measurement's exact id set was
never committed (no `_work/testdata/similar_pairs.tl` landed with it),
so this pass re-derived its own labeled set directly from the current
board, verifying every pick against the items' own `resolution`/`pr`
fields and spec text (a `not-planned` item whose spec says "same as
X"/"same shape as Y" is strong, checkable evidence of a real
duplicate/overlap; a `completed` item with its *own* PR number,
independent of any sibling's PR, is strong evidence of a genuinely
separate piece of work). This surfaced several near-miss picks — see
`## Friction` and the out-of-scope paragraph below — that were swapped
out before scoring.

Four pairs (one identical-title, three differently-phrased about the
same binding, each verified via `gitboard show`: a `not-planned` item
resolved in favor of a `completed` sibling covering the same
function):

| # | id | title |
|---|----|-------|
| 1a | `3IkbPrwvC6zafqQREtMUp8eoaDa` | definitions coverage check 9: whitespace before a depth-0 '\|' still passes, and gentype drops everything after it from the type |
| 1b | `3IkbRV5WrHaqvLSPc2Q8vnuzF5o` | (identical title) |
| 2a | `3IiuLzg3ht2L0LYdpXks1wAh7VN` | cosmo.re: re.search's slot 2 shares the captures table with the error string |
| 2b | `3IjOWuORT13EK15yWIo4cHhpHnN` | re.search: capture-groups slot doubles as the error string, same shape as Regex:search |
| 3a | `3IiuEB99e5PMeFcuuCUA6BTPuE8` | cosmo.re: re.Regex:search's slot 2 shares the captures table with the error string |
| 3b | `3IjOVudLEpXmQizdTC0pewxEYUJ` | re.Regex:search: capture-groups slot doubles as the error string on engine failure |
| 4a | `3IjOWa8CPSsln1sRgvtSIRNMxf9` | re.Regex:find: stop-offset slot doubles as the error string on engine failure |
| 4b | `3IiuLdfU5CIDPEZxh5IZotdW0Zj` | cosmo.re: re.Regex:find's slot 2 shares the stop offset with the error string |

Twenty controls (verified: each has its own independent PR or is a
census/friction/root item with no sibling overlap; the closest-other
title in each row is a distinct binding/path/batch/module, never the
same underlying change):

`3I7LNDrF8xtDAFxhpam8hpP0WuR`, `3IlWQD7zZy8JUybZvrNA1MxsGl8`,
`3HyRdGk0liOSXEXjHRReYYEUxdi`, `3IqUE8wn7UTeFFMvJZKUBhkKR40`,
`3Iiv1T1cnZkPE4JPf9JfHSkSCge`, `3Ishsx4KJY6ieljoltFMMAPGdf6`,
`3IR2TpB3LzucKMLBikykPjHSBKS`, `3IqJ0yKpGJrCIJjmllrEMdbHFX2`,
`3IlWQyn7zXEQPpAZ3WFfjlJt7fe`, `3IjVAM5WZr0k0LbJVc2NLZhtZCk`,
`3IU6BjUIPUntCq03oooMyT6pmLS`, `3IR2RpK9Fvcw40NFlHfjyorwi5s`,
`3IjgAdBAQvmdf8rkZDIMWw2I7M7`, `3IptmlaFwaGNOmguaiefU6lyGKY`,
`3IU6AZExaHemD7J7BUV51EqhwmG`, `3IU6AsZCkkWRx5KsSpAAJ3fUQ48`,
`3IR2SFOqEXQ4luAS8FK0Km2AzEa`, `3IR2U42tzzZaV7nMWHqYloPx1CX`,
`3IlWQg85ivWuWeZ1rNrydJqpvn8`, `3IlWQRo5ACXdVZciyvNpPFVvAJz`

**Signal A — TF-IDF over title+spec, tokens from a real `search` FTS5
table (`porter unicode61`), standard idf, cosine:**

- Pair true-match scores: 0.9161, 0.5859, 0.5998, 0.5674 → **min 0.5674**
- Control closest-other scores: 0.3271–0.8627 (mean ≈0.53) → **max 0.8627**
  (the 0.8627 outlier is two `migrate to runner mode` batches, an
  intentionally sequential, textually near-identical, genuinely
  unrelated family)
- **Margin = min(pairs) − max(controls) = 0.5674 − 0.8627 = −0.2953**

**Signal B — hashed character 3-gram of the title only, dim 512,
FNV-1a 32-bit, cosine:**

- Pair true-match scores: 1.0000, 0.6122, 0.6254, 0.6050 → **min 0.6050**
- Control closest-other scores: 0.5951–0.9265 (mean ≈0.78) → **max 0.9265**
  (the 0.9265 outlier: two `cosmos pin bump` items, "ABI 5-9" vs
  "ABI-4" — near-identical template, genuinely different releases)
- **Margin = 0.6050 − 0.9265 = −0.3215**

**Decision: neither signal ships.** Both margins are not merely short
of the +0.10 bar, they are decisively negative — a template-family
control (a differently-numbered batch/binding/release) routinely
outscores the worst genuine, differently-phrased duplicate pair. The
identical-title pair alone separates trivially under any signal
(1.00/1.00/0.92); every non-trivial (differently-phrased) pair sits
*below* several controls under both TF-IDF and hashed trigrams, exactly
reproducing the original bm25 finding's shape with two new signals.
Bag-of-words/character-shingle text similarity, offline, cannot tell
"the same underlying binding, worded differently" from "a different
binding, worded from the same template" on this board — the discriminator
duplicates share is *meaning*, not shared tokens or shingles, which is
exactly what only a semantic embedding reaches.

**Extension check (per step 5):** `grep -n load_extension` against a
freshly generated `o/_types/types_gen/cosmo/lsqlite3.d.tl` returns no
matches — there is no dynamic extension loading at all. The only
registration surface is `register_extension` over a fixed,
statically-linked registry (`decimal`, `fileio`, `ieee`, `regexp`,
`series`, `sha`, `shathree`, `sqlar`, `stmtrand`, `uint`, `zipfile`) —
no vector/ANN extension is linked or loadable. This confirms
sqlite-vec is unavailable and brute-force cosine in Teal is the only
path for the remote stage, exactly as this item's Change already
assumed.

**Fixture file not yet committed.** This was a read-only research
slice (no repo diff); `_work/testdata/similar_pairs.tl` does not exist
yet. The follow-up item includes creating it, from the id lists above,
as its first concrete step (regenerated via `store.list` +
`store.read_specs` over these exact ids so the embedded title/spec text
is byte-identical to the live items — see that item's Change step 1
for the exact recipe).

**Follow-up filed:** «gitboard: a remote embedding stage over a cached
vectors table, offline fallback when a row is missing», parented under
this item's own parent (3HyRdT1J — G8, the flow system), carrying the
Change spelled out above (fixture, cache schema, `_work/embed.tl`,
`similar`'s cosine engine, the offline fallback, and the fixture-backed
test).
