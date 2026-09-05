## Evidence

Exact-duplicate prose is a hash lookup (the sibling item that gates it). What a gate
cannot see is the paragraph pasted and then re-worded: same claim, different
inflections, one sentence dropped. Those are the copies that DISAGREE later, and the
tree has them — the `_build/casts.tl`/`_build/nil_returns.tl` pair shares three
byte-identical paragraphs (the exact gate's finding) and reads as near-identical for
most of its length.

FTS5 makes the near-duplicate question cheap to ask: index every prose block, then for
each block run its own distinct terms as an OR-query and take the best OTHER hit's
`bm25()` as a ratio of the block's own self-score. Measured 2026-09-05 at c39fc2f,
`o/bin/cosmic` built from the tree (FTS5 present; the pinned release lacks it):

```
indexed 714 files, 4876 blocks in 266 ms          (doc comments + markdown paragraphs,
                                                   tokenize = 'porter unicode61')
2682 candidate blocks scanned in 19129 ms; 214 pairs above 0.72   (blocks of 25–120 tokens,
                                                   12+ distinct non-stopword terms)
  1.01  cosmic/fs/find.tl:20  ~  cosmic/fs/find.tl:395
        "Convert a glob pattern to a Lua pattern. Supports * (any run) and ? (o"
```

The exact duplicates score 1.00; the interesting band is below it, and its threshold is
unknown. `_work/find.tl`'s header records what happens when a bm25 ratio is trusted
without measuring: over 914 board titles, true duplicate pairs scored 1.00, 0.62, 0.40
and 0.27 while unrelated titles' closest neighbours ranged 0.21–0.91, so no threshold
separated them and `SIMILAR_RATIO` stayed a guess. Prose blocks are longer than titles
(25–120 tokens against 8–15), which is the one reason to expect better separation here;
whether it holds is the question this item answers, and a report with a measured
threshold is worth shipping while a gate with a guessed one is not.

The 19 s scan is one query per candidate block (2682 queries, ~7 ms each, most of it
the 30–80-term OR expression). A per-file scope (`--make run _tool/prose_similar.tl
cosmic/fs`) is proportionally cheaper; the whole-tree pass is a report a session runs
on purpose, never a gate stage.

## Change

Research with one shippable outcome; deliverable is a `--result` handover with the
measurements below and the follow-up item(s).

1. **Fixture.** `_tool/testdata/prose_pairs.tl`, a literal table (`cosmic.literal`)
   of hand-labelled pairs from the tree at a named sha: at least 10 TRUE near-duplicates
   (start from the 19 exact groups the sibling item lists, before that item cleans them,
   plus re-worded copies found by reading the 214 pairs above 0.72 — paste the ones
   kept) and at least 20 CONTROLS: blocks whose top hit is topically related and not a
   copy (two functions in one module documenting adjacent behavior). Every later
   signal is scored on this set.
2. **Signal A, bm25 self-ratio** as prototyped: OR-query of the block's distinct
   terms (stopwords dropped, 3+ characters), `bm25()` of the best other hit over the
   block's own score. Score the fixture; paste every pair's ratio and every control's
   closest-other ratio.
3. **Signal B, token-set Jaccard** over the same `porter unicode61` tokens, read back
   from an `fts5vocab` instance-level table so nothing new is tokenized. Same scoring.
4. **Decision rule, stated before measuring:** a signal ships when every true pair
   scores above every control by a margin of at least 0.10. If A or B passes, the
   follow-up is one item: `_tool/prose_similar.tl` (a `--make run` report: `path:line ~
   path:line  ratio` per pair above the measured threshold, symmetric pairs collapsed,
   scope narrowed by paths) with `_tool/prose_similar_test.tl` holding the margin on the
   fixture. It stays a report — a session runs it before a docs sweep and decides — and
   never a gate, because a near-duplicate has a legitimate form (two modules restating
   one contract in their own words) the exact gate cannot mistake but a threshold can.
5. If neither passes: record the spreads and end the line here; the exact gate is the
   whole enforcement, and the report is not built on a signal that does not separate.

Ready when: `o/bin/cosmic -e 'local db=assert(require("cosmic.sqlite").open(":memory:"));
print(db:query_one("SELECT 1 AS ok FROM pragma_module_list WHERE name=?", {"fts5"}) and
"present" or "absent")'` prints `present` — true after `bin/cosmic --make build` at this
tree's cosmos pin; the report runs under the built binary via `--make run`, never the
pinned release.

## Result (measured 2026-09-05, tree d3bce22, `o/bin/cosmic` built fresh)

Readiness probe reproduced: prints `present`. Approach reproduced at scale: a from-scratch
extractor (doc-comment paragraphs split on a blank `---` separator line; markdown
paragraphs split on blank lines, excluding headings/fences/lists/tables) over the whole
tree (excluding `o/`, `3p/`, `testdata/`, and `CLAUDE.md` — a symlink to `AGENTS.md`,
see Friction) found 707 files / 5598 blocks in ~1 s, 3053 candidate blocks (25–120
tokens, 12+ distinct non-stopword terms ≥3 chars), 326 pairs above 0.72 in ~21 s —
same order of magnitude as the prototype's 714/4876/2682/19129 ms/214, confirming the
question is answerable at this scale without re-deriving the exact extraction rule.

**Fixture** (25 TRUE blocks across 14 near-duplicate pairs/groups, 35 CONTROL blocks,
all named `path:line` against tree d3bce22 — well over the 10/20 minimums):

TRUE pairs (bm25 self-ratio / best-other, both directions where computed):
| block | bm25 ratio | best other |
|---|---|---|
| `_build/casts.tl:83` | 0.9166 | `_build/nil_returns.tl:146` |
| `_build/nil_returns.tl:146` | 0.9976 | `_build/casts.tl:83` |
| `_build/casts.tl:48` | 0.9414 | `_build/nil_returns.tl:85` |
| `_build/nil_returns.tl:85` | **0.8871** | `_build/casts.tl:48` |
| `_make/readstamp.tl:37` | 0.9939 | `_make/refstamp.tl:42` |
| `_make/envstamp.tl:29` | 0.9899 | `_make/readstamp.tl:37` |
| `_make/readstamp.tl:65` | 0.9154 | `_make/envstamp.tl:69` |
| `_make/envstamp.tl:69` | 0.9360 | `_make/refstamp.tl:106` |
| `_make/refstamp.tl:42` | 0.9415 | `_make/readstamp.tl:37` |
| `_make/refstamp.tl:106` | 0.9299 | `_make/envstamp.tl:69` |
| `cosmic/url.tl:351` (safe_path) | 0.9631 | `cosmic/url.tl:360` |
| `cosmic/url.tl:360` (safe_segment) | 0.9881 | `cosmic/url.tl:369` |
| `cosmic/url.tl:369` (safe_host) | 0.9448 | `cosmic/url.tl:360` |
| `cosmic/url.tl:378` (safe_fragment) | 0.9143 | `cosmic/url.tl:360` |
| `cosmic/url.tl:387` (safe_param) | 0.9296 | `cosmic/url.tl:360` |
| `cosmic/fs/find.tl:20` | 1.0000 | `cosmic/fs/find.tl:395` |
| `cosmic/fs/find.tl:395` | 1.0000 | `cosmic/fs/find.tl:20` |
| `docs/guides/checking.md:125` | 0.9353 | `docs/guides/gotchas.md:132` |
| `docs/guides/gotchas.md:132` | 0.9226 | `docs/guides/checking.md:125` |
| `cosmic/sandbox/landlock.tl:159` | 0.9713 | `cosmic/quicksand/caps.tl:46` |
| `cosmic/quicksand/caps.tl:46` | 0.8913 | `cosmic/sandbox/landlock.tl:159` |
| `_tool/coverage/baseline_test.tl:27` | 0.9872 | `_tool/coverage/baseline_corpus_guard_test.tl:24` |
| `_tool/coverage/baseline_corpus_guard_test.tl:24` | 1.0130 | `_tool/coverage/baseline_test.tl:27` |
| `_eval/checks/contained-task.tl:16` | 0.9716 | `_eval/checks/child-tcp.tl:57` |
| `_eval/checks/multi-module-build.tl:39` | 1.0382 | `_eval/checks/contained-task.tl:16` |

CONTROL blocks (bm25 self-ratio / closest-other, all genuinely different-content
adjacent functions or doc paragraphs, not copies):
| block | bm25 ratio | closest other |
|---|---|---|
| `cosmic/fs/dir.tl:72` (stat) | 0.8553 | `cosmic/fs/dir.tl:86` |
| `cosmic/fs/dir.tl:86` (stat_link) | **0.9760** | `cosmic/fs/dir.tl:72` |
| `cosmic/fs/dir.tl:113` (make_dir) | 0.8794 | `cosmic/fs/dir.tl:128` |
| `cosmic/fs/dir.tl:128` (make_dirs) | 0.9420 | `cosmic/fs/dir.tl:113` |
| `cosmic/string.tl:251` (pad_left) | 0.9688 | `cosmic/string.tl:270` |
| `cosmic/string.tl:270` (pad_right) | 0.9677 | `cosmic/string.tl:251` |
| `cosmic/check.tl:56` | 0.7677 | `cosmic/check.tl:77` |
| `cosmic/check.tl:77` (equal) | 0.9026 | `cosmic/check.tl:56` |
| `cosmic/signal.tl:149` (kill) | 0.9036 | `cosmic/signal.tl:162` |
| `cosmic/signal.tl:162` (kill group) | 0.8097 | `cosmic/signal.tl:149` |
| `cosmic/time.tl:273` | 0.8653 | `cosmic/time.tl:299` |
| `cosmic/time.tl:299` | 0.8947 | `cosmic/time.tl:273` |
| `cosmic/codec.tl:72` (decode_base64) | 0.9006 | `cosmic/codec.tl:102` |
| `cosmic/codec.tl:102` (encode_base64url) | 0.7562 | `cosmic/codec.tl:72` |
| `cosmic/proc/rusage.tl:36` (getrlimit) | 0.8767 | `cosmic/proc/rusage.tl:50` |
| `cosmic/proc/rusage.tl:50` (setrlimit) | 0.6992 | `cosmic/proc/rusage.tl:36` |
| `cosmic/proc/rusage.tl:82` (getpriority) | 0.8832 | `cosmic/proc/rusage.tl:95` |
| `cosmic/proc/rusage.tl:95` (setpriority) | 0.7035 | `cosmic/proc/rusage.tl:82` |
| `cosmic/_teal_engine.tl:187` (process_source) | 0.8822 | `cosmic/_teal_engine.tl:265` |
| `cosmic/_teal_engine.tl:265` (process file) | 0.8709 | `cosmic/_teal_engine.tl:187` |
| `cosmic/fs/path.tl:41` (is_file) | 0.9096 | `cosmic/fs/path.tl:52` |
| `cosmic/fs/path.tl:52` (is_dir) | 0.9329 | `cosmic/fs/path.tl:41` |
| `cosmic/fs/ops.tl:401` (statfs) | 0.9113 | `cosmic/fs/ops.tl:414` |
| `cosmic/fs/ops.tl:414` (statfs_fd) | 0.6423 | `cosmic/fs/ops.tl:401` |
| `cosmic/user.tl:72` (setresuid) | 0.9606 | `cosmic/user.tl:87` |
| `cosmic/user.tl:87` (setresgid) | 0.9117 | `cosmic/user.tl:72` |
| `cosmic/sandbox/unveil.tl:54` | 0.8786 | `cosmic/sandbox/pledge.tl:72` |
| `cosmic/sandbox/pledge.tl:72` | 0.8041 | `cosmic/sandbox/unveil.tl:54` |
| `cosmic/fetch/verbs_test.tl:42` | 0.9156 | `cosmic/fetch/init_test.tl:30` |
| `cosmic/fetch/init_test.tl:30` | 0.8236 | `cosmic/fetch/verbs_test.tl:42` |
| `_perf/gate.tl:172` | 0.8671 | `_perf/gate.tl:333` |
| `_perf/gate.tl:333` | 0.8752 | `_perf/gate.tl:172` |
| `_tool/example.tl:201` | 0.8699 | `_tool/benchmark.tl:228` |
| `_tool/benchmark.tl:228` | 0.7203 | `_tool/example.tl:201` |
| `_make/policy_test.tl:124` | 0.9163 | `_tool/coverage/baseline_test.tl:27` |

**Signal A (bm25 self-ratio): worst TRUE = 0.8871, best CONTROL = 0.9760 →
margin = −0.0890. FAILS** the ≥0.10 margin rule outright — multiple controls
(`dir.tl` stat/stat_link 0.976, `string.tl` pad_left/pad_right 0.968/0.968,
`user.tl` setresuid/setresgid 0.961, `_make/policy_test.tl` 0.916, `fs/path.tl`
is_file/is_dir 0.910/0.933) score as high as or higher than genuine reworded
near-duplicates (`nil_returns.tl:85`~`casts.tl:48` 0.887, `caps.tl:46`~`landlock.tl:159`
0.891, `url.tl:378` (safe_fragment) 0.914). The bands fully overlap; there is no
threshold, guessed or measured, that separates them. This reproduces, on prose
blocks, the exact failure mode `_work/find.tl` recorded on board titles.

**Signal B (token-set Jaccard, read from `fts5vocab`'s instance table, same
`porter unicode61` tokens, no re-tokenizing): worst TRUE = 0.6667, best CONTROL =
0.9677 → margin = −0.3011. FAILS more decisively than Signal A** — e.g.
`cosmic/user.tl:87`~`:72` (a genuine control: setresgid vs. setresuid, same
boilerplate phrasing) scores 0.9677 Jaccard, higher than all but the exact and
near-exact TRUE pairs. Unlike bm25, plain Jaccard carries no IDF term-weighting,
so the shared scaffolding vocabulary every doc comment in this style uses (`@param`,
`string`, `boolean`, `Error`, `message`, `on`, `failure`, ...) inflates every
pair's score roughly uniformly, control and duplicate alike, and separates worse than
Signal A rather than better.

**Decision (Change step 4/5): neither signal clears the required 0.10 margin, and
both margins are negative — CONTROL blocks actually outscore the weakest TRUE
near-duplicates on both signals.** Per step 5, the line ends here: the exact-duplicate
gate remains the whole enforcement for prose; no `_tool/prose_similar.tl` /
`_tool/prose_similar_test.tl` follow-up is warranted, and none is filed. Recommend
closing this item with this record as its final state.

Implementation notes for anyone attempting a different signal later: (1) the block
extraction above (doc-comment paragraphs split on a blank `---` line; markdown
paragraphs split on blank lines) is a reasonable approximation, not the sibling gate's
exact rule — re-derive candidate counts before trusting them precisely. (2) A naive
per-term-then-per-matching-doc Jaccard implementation is an O(fixture × terms × docs)
query explosion that runs for minutes without progress; batch each candidate's
shared-term lookup into one grouped `... WHERE term IN (...) GROUP BY doc` query and
precompute per-doc term counts with a single upfront `GROUP BY doc` pass first.

Two out-of-scope findings surfaced while building the fixture were filed as their own
items, both under this item's parent, both targeted at the sibling exact-duplicate
gate item («iltX_EM90»): «cY1cArl» (`CLAUDE.md`/`AGENTS.md`, a symlink pair, will read
as spurious 1.00-ratio self-duplicates to any scanner that doesn't dedupe by realpath)
and «LOP1MhAs» (6+ `_eval/checks/*.tl` files share a verbatim, legitimate
interface-contract doc comment at bm25 ≈1.00–1.04 — a decision the exact gate needs
before day one). Neither is a follow-up of THIS item's own signal research (both
signals failed; no `_tool/prose_similar.tl` is filed or warranted) — they are
independent defects the fixture-building process happened to surface.

## Non-goals

A gate. Semantic or vector similarity («Pszd_rIKz» records why not). Comment quality.
Board items (their own sweep is «va0I_6MWO»). The exact-duplicate gate, filed beside
this one, which lands regardless of this item's outcome.
