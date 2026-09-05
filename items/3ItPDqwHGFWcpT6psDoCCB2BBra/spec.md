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

## Result (round 2, re-measured 2026-09-05, tree dfabadf, `o/bin/cosmic` built fresh)

Readiness probe reproduced: prints `present`. A fresh from-scratch extractor and FTS5
index (doc-comment paragraphs split on a blank `---` separator line; markdown
paragraphs split on blank lines, excluding headings/fences/lists/tables; `o/`, `3p/`,
`testdata/`, and any file that is itself a symlink excluded) over the whole tree found
607 files / 6229 blocks — same order of magnitude as round 1's 707/5598 at the earlier
commit d3bce22, confirming the approach still holds at this tree state. This pass did
not re-run the whole-tree pairs-above-0.72 candidate scan (round 1's 714/4876/2682/214
scale numbers were not disputed by review and are not re-verified here); it rebuilds
and re-scores only the fixture below, which IS what review disputed.

### The fixture's TRUE/CONTROL rule (round 2 fix)

Round 1's fixture had no stated rule for template-with-word-swap doc comments, and
applied its unstated rule inconsistently: `cosmic/url.tl`'s `safe_param/safe_path/
safe_segment/safe_host/safe_fragment` family (one doc-comment block repeated per
sibling, target noun swapped) was labeled TRUE, while five structurally identical
pairs — `cosmic/user.tl:72,87`, `cosmic/fs/path.tl:41,52`, `cosmic/string.tl:251,270`,
`cosmic/fs/dir.tl:72,86`, and `cosmic/proc/rusage.tl`'s getter/setter pairs — were
labeled CONTROL. This inflated both signals' apparent failure (the flagship "control
beats true duplicate" example for both signals was the same mislabeled pair).

**Stated rule:** a pair of same-shape, adjacently-placed doc-comment blocks (siblings:
two functions with parallel roles in one module) is a **TRUE** near-duplicate when
every differing clause between them is a REWORDING, CONTRACTION, or DIRECTIONAL
RESTATEMENT of the *same* underlying claim — no sentence in either introduces a fact,
mechanism, or constraint that has no analogue, however differently phrased, in the
other. It is **CONTROL** when at least one sibling's prose states something the other
CANNOT state because the operations are asymmetric in kind — a setter's clamping or
privilege rule with no getter counterpart, a distinct enumerated case one function
handles and the other structurally cannot — genuinely additional information, not a
paraphrase of shared content.

This rule is calibrated against the fixture's own existing (unflagged) TRUE entries,
not just against the disputed ones — `_build/casts.tl:48` and `_build/nil_returns.tl:85`
already disagree by a WHOLE sentence ("A file's count is its number of lines holding an
`as`, one line counting at most once." has no counterpart in the other) and are
correctly TRUE regardless: both sentences restate the *same* claim (what counts as
absent, what fails silently) rather than introducing a new fact. A whole differing
sentence is therefore not by itself disqualifying; what disqualifies is a sentence that
could not, even reworded, appear on the other sibling because the two operations are
not describing the same thing.

Applying the rule (content read directly, quoted below):

| pair | verdict | why |
|---|---|---|
| `user.tl:72` (setresuid) / `:87` (setresgid) | **TRUE** | "Set real, effective, and saved user/group IDs. Pass -1 for any argument to leave that ID unchanged." — identical prose, only the ID-kind noun swapped throughout, including every `@param` description. |
| `fs/path.tl:41` (is_file) / `:52` (is_dir) | **TRUE** | "Symbolic links are followed (uses stat), matching POSIX `test -f`/`test -d`, Python, and Node: a symlink to a regular file/directory counts as a regular file/directory. Use is_link() to detect the symlink itself." — same sentence, same clause order, only the file-kind noun swapped, every time it appears. |
| `string.tl:251` (pad_left) / `:270` (pad_right) | **TRUE** | sentence 1 differs only in "left"/"right"; the entire remaining paragraph and `@param`/`@return` are byte-identical. |
| `fs/dir.tl:72` (stat) / `:86` (stat_link) | **TRUE** | stat: "Follows symbolic links: stat on a symlink describes its target. Use stat_link() to inspect the symlink itself." / stat_link: "On a symlink this describes the link itself, not its target." — the same single fact (follow vs. no-follow symlink semantics) stated from each direction; neither adds a fact absent from the other. The `@return` lines are byte-identical in both. |
| `proc/rusage.tl:82` (getpriority) / `:95` (setpriority) | **TRUE** | "Gets/Sets the scheduling priority of a process, process group, or user." plus byte-identical `@param which`; `@param who`'s only difference is "to query"/"to modify". setpriority's extra `@param prio` and its boolean `@return` (vs. getpriority's integer `@return`) are the structurally-necessary shape of any getter/setter pair, not a new prose fact. |
| `proc/rusage.tl:36` (getrlimit) / `:50` (setrlimit) | **stays CONTROL** | setrlimit's prose carries two whole sentences with no getrlimit counterpart, in kind: "The soft limit can be raised up to the hard limit. Only privileged processes can raise the hard limit." — a clamping/privilege rule that a pure getter has nothing to restate, reworded or not. This is genuinely additional information, unlike the getpriority/setpriority pair above. |

Note the last row: the review's phrase "rusage.tl's getter/setter pairs" (plural) reads
as covering both of rusage.tl's pairs. Applying the SAME stated rule to both, only
getpriority/setpriority passes it; getrlimit/setrlimit does not, and is kept CONTROL on
that basis rather than moved by default.

Net effect: 5 pairs (10 blocks) move CONTROL → TRUE. The corrected fixture is **35 TRUE
blocks** (the original 25 plus these 10) and **25 CONTROL blocks** (the original 35
minus these 10), still well over the 10/20 minimums. `cosmic/url.tl`'s own family had a
labeling slip worth fixing while rebuilding this table: line 351 is `safe_param` (not
`safe_path`), 360 is `safe_path` (not `safe_segment`), 369 is `safe_segment` (not
`safe_host`), 378 is `safe_host` (not `safe_fragment`), 387 is `safe_fragment` (not
`safe_param`) — the ratios were always keyed to the correct LINE, only the parenthetical
name was shifted by one function; corrected below. `codec.tl:102` is `decode_base64url`,
not `encode_base64url` (at line 89) — same kind of slip, also corrected.

### Signal A (bm25 self-ratio) — full table

TRUE blocks (both directions where computed; `./` paths as indexed, line numbers
current at dfabadf — `docs/guides/gotchas.md`'s matching paragraph moved from line 132
to 155 since d3bce22, content unchanged):

| block | bm25 ratio | best other |
|---|---|---|
| `_build/casts.tl:83` | 0.8799 | `_build/nil_returns.tl:146` |
| `_build/nil_returns.tl:146` | 1.0168 | `_build/casts.tl:83` |
| `_build/casts.tl:48` | 0.9287 | `_build/nil_returns.tl:85` |
| `_build/nil_returns.tl:85` | 0.8907 | `_build/casts.tl:48` |
| `_make/readstamp.tl:37` | 0.9931 | `_make/refstamp.tl:42` |
| `_make/envstamp.tl:29` | 0.9888 | `_make/readstamp.tl:37` |
| `_make/readstamp.tl:65` | 0.9034 | `_make/envstamp.tl:69` |
| `_make/envstamp.tl:69` | 0.9309 | `_make/refstamp.tl:106` |
| `_make/refstamp.tl:42` | 0.9404 | `_make/readstamp.tl:37` |
| `_make/refstamp.tl:106` | 0.9254 | `_make/envstamp.tl:69` |
| `cosmic/url.tl:351` (safe_param) | 0.9624 | `cosmic/url.tl:360` |
| `cosmic/url.tl:360` (safe_path) | 0.9867 | `cosmic/url.tl:369` |
| `cosmic/url.tl:369` (safe_segment) | 0.9407 | `cosmic/url.tl:360` |
| `cosmic/url.tl:378` (safe_host) | 0.9086 | `cosmic/url.tl:360` |
| `cosmic/url.tl:387` (safe_fragment) | 0.9250 | `cosmic/url.tl:360` |
| `cosmic/fs/find.tl:20` | 1.0000 | `cosmic/fs/find.tl:395` |
| `cosmic/fs/find.tl:395` | 1.0000 | `cosmic/fs/find.tl:20` |
| `docs/guides/checking.md:125` | 0.9303 | `docs/guides/gotchas.md:155` |
| `docs/guides/gotchas.md:155` | 0.9626 | `docs/guides/checking.md:125` |
| `cosmic/sandbox/landlock.tl:159` | 0.9689 | `cosmic/quicksand/caps.tl:46` |
| `cosmic/quicksand/caps.tl:46` | 0.8925 | `cosmic/sandbox/landlock.tl:159` |
| `_tool/coverage/baseline_test.tl:27` | 0.9861 | `_tool/coverage/baseline_corpus_guard_test.tl:24` |
| `_tool/coverage/baseline_corpus_guard_test.tl:24` | 1.0141 | `_tool/coverage/baseline_test.tl:27` |
| `_eval/checks/contained-task.tl:16` | 0.9670 | `_eval/checks/child-tcp.tl:57` |
| `_eval/checks/multi-module-build.tl:39` | 1.0440 | `_eval/checks/contained-task.tl:16` |
| `cosmic/user.tl:72` (setresuid) | 0.9539 | `cosmic/user.tl:87` |
| `cosmic/user.tl:87` (setresgid) | 0.9000 | `cosmic/user.tl:72` |
| `cosmic/fs/path.tl:41` (is_file) | 0.8984 | `cosmic/fs/path.tl:52` |
| `cosmic/fs/path.tl:52` (is_dir) | 0.9261 | `cosmic/fs/path.tl:41` |
| `cosmic/string.tl:251` (pad_left) | 0.9661 | `cosmic/string.tl:270` |
| `cosmic/string.tl:270` (pad_right) | 0.9655 | `cosmic/string.tl:251` |
| `cosmic/fs/dir.tl:72` (stat) | 0.8412 | `cosmic/fs/dir.tl:86` |
| `cosmic/fs/dir.tl:86` (stat_link) | 1.0171 | `cosmic/fs/dir.tl:72` |
| `cosmic/proc/rusage.tl:82` (getpriority) | 0.9024 | `cosmic/proc/rusage.tl:95` |
| `cosmic/proc/rusage.tl:95` (setpriority) | **0.7166** | `cosmic/proc/rusage.tl:82` |

CONTROL blocks (all genuinely different-content adjacent functions or doc paragraphs,
not copies, by the stated rule):

| block | bm25 ratio | closest other |
|---|---|---|
| `cosmic/fs/dir.tl:113` (make_dir) | 0.8502 | `cosmic/fs/dir.tl:128` |
| `cosmic/fs/dir.tl:128` (make_dirs) | **0.9378** | `cosmic/fs/dir.tl:113` |
| `cosmic/check.tl:56` (not_equal) | 0.7783 | `cosmic/check.tl:77` |
| `cosmic/check.tl:77` (equal) | 0.8866 | `cosmic/check.tl:56` |
| `cosmic/signal.tl:149` (kill) | 0.8777 | `cosmic/signal.tl:162` |
| `cosmic/signal.tl:162` (killpg) | 0.7837 | `cosmic/signal.tl:149` |
| `cosmic/time.tl:273` (format_date) | 0.8425 | `cosmic/time.tl:299` |
| `cosmic/time.tl:299` (format_iso8601) | 0.8728 | `cosmic/time.tl:273` |
| `cosmic/codec.tl:72` (decode_base64) | 0.7661 | `cosmic/codec.tl:102` |
| `cosmic/codec.tl:102` (decode_base64url) | 0.6396 | `cosmic/codec.tl:72` |
| `cosmic/proc/rusage.tl:36` (getrlimit) | 0.8877 | `cosmic/proc/rusage.tl:50` |
| `cosmic/proc/rusage.tl:50` (setrlimit) | 0.7433 | `cosmic/proc/rusage.tl:36` |
| `cosmic/_teal_engine.tl:187` (process_source) | 0.8809 | `cosmic/_teal_engine.tl:265` |
| `cosmic/_teal_engine.tl:265` (process_file) | 0.8548 | `cosmic/_teal_engine.tl:187` |
| `cosmic/fs/ops.tl:401` (statfs) | 0.9012 | `cosmic/fs/ops.tl:414` |
| `cosmic/fs/ops.tl:414` (statfs_fd) | 0.6198 | `cosmic/fs/ops.tl:401` |
| `cosmic/sandbox/unveil.tl:54` | 0.8752 | `cosmic/sandbox/pledge.tl:72` |
| `cosmic/sandbox/pledge.tl:72` | 0.7807 | `cosmic/sandbox/unveil.tl:54` |
| `cosmic/fetch/verbs_test.tl:42` | 0.9110 | `cosmic/fetch/init_test.tl:30` |
| `cosmic/fetch/init_test.tl:30` | 0.8454 | `cosmic/fetch/verbs_test.tl:42` |
| `_perf/gate.tl:172` | 0.9133 | `_perf/gate.tl:333` |
| `_perf/gate.tl:333` | 0.9007 | `_perf/gate.tl:172` |
| `_tool/example.tl:201` | 0.8642 | `_tool/benchmark.tl:228` |
| `_tool/benchmark.tl:228` | 0.7156 | `_tool/example.tl:201` |
| `_make/policy_test.tl:124` | 0.9085 | `_tool/coverage/baseline_test.tl:27` |

**Signal A: worst TRUE = 0.7166 (`proc/rusage.tl:95` setpriority), best CONTROL =
0.9378 (`fs/dir.tl:128` make_dirs) → margin = −0.2212. FAILS.** Corrected labeling
removes the disputed pair from CONTROL, but the margin is not merely restored to
positive — it is now MORE decisively negative than round 1's reported −0.0890, because
the newly-TRUE `setpriority`/`getpriority` pair (0.9024/0.7166) sits well below several
still-legitimate CONTROLs (`make_dirs` 0.9378, `_perf/gate.tl` 0.9133/0.9007, `fs/ops.tl
statfs` 0.9012, `fetch/verbs_test.tl` 0.9110, `_make/policy_test.tl` 0.9085). The bands
still fully overlap under a correctly-labeled fixture.

### Signal B (token-set Jaccard, `fts5vocab` instance table, no re-tokenizing) — full table

TRUE blocks:

| block | Jaccard | best other |
|---|---|---|
| `_build/casts.tl:83` | 0.9643 | `_build/nil_returns.tl:146` |
| `_build/nil_returns.tl:146` | 0.9643 | `_build/casts.tl:83` |
| `_build/casts.tl:48` | 0.8143 | `_build/nil_returns.tl:85` |
| `_build/nil_returns.tl:85` | 0.8143 | `_build/casts.tl:48` |
| `_make/readstamp.tl:37` | 0.9400 | `_make/envstamp.tl:29` |
| `_make/envstamp.tl:29` | 0.9400 | `_make/readstamp.tl:37` |
| `_make/readstamp.tl:65` | **0.6667** | `_make/envstamp.tl:69` |
| `_make/envstamp.tl:69` | 0.8814 | `_make/refstamp.tl:106` |
| `_make/refstamp.tl:42` | 0.8200 | `_make/readstamp.tl:37` |
| `_make/refstamp.tl:106` | 0.8814 | `_make/envstamp.tl:69` |
| `cosmic/url.tl:351` (safe_param) | 0.9474 | `cosmic/url.tl:360` |
| `cosmic/url.tl:360` (safe_path) | 0.9737 | `cosmic/url.tl:369` |
| `cosmic/url.tl:369` (safe_segment) | 0.9737 | `cosmic/url.tl:360` |
| `cosmic/url.tl:378` (safe_host) | 0.9231 | `cosmic/url.tl:351` |
| `cosmic/url.tl:387` (safe_fragment) | 0.9474 | `cosmic/url.tl:351` |
| `cosmic/fs/find.tl:20` | 1.0000 | `cosmic/fs/find.tl:395` |
| `cosmic/fs/find.tl:395` | 1.0000 | `cosmic/fs/find.tl:20` |
| `docs/guides/checking.md:125` | 0.7667 | `docs/guides/gotchas.md:155` |
| `docs/guides/gotchas.md:155` | 0.7667 | `docs/guides/checking.md:125` |
| `cosmic/sandbox/landlock.tl:159` | 0.8333 | `cosmic/quicksand/caps.tl:46` |
| `cosmic/quicksand/caps.tl:46` | 0.8333 | `cosmic/sandbox/landlock.tl:159` |
| `_tool/coverage/baseline_test.tl:27` | 0.9091 | `_tool/coverage/baseline_corpus_guard_test.tl:24` |
| `_tool/coverage/baseline_corpus_guard_test.tl:24` | 0.9091 | `_tool/coverage/baseline_test.tl:27` |
| `_eval/checks/contained-task.tl:16` | 0.8889 | `_eval/checks/child-tcp.tl:57` |
| `_eval/checks/multi-module-build.tl:39` | 0.8929 | `_eval/checks/module-tests.tl:22` |
| `cosmic/user.tl:72` (setresuid) | 0.9677 | `cosmic/user.tl:87` |
| `cosmic/user.tl:87` (setresgid) | 0.9677 | `cosmic/user.tl:72` |
| `cosmic/fs/path.tl:41` (is_file) | 0.8780 | `cosmic/fs/path.tl:52` |
| `cosmic/fs/path.tl:52` (is_dir) | 0.8780 | `cosmic/fs/path.tl:41` |
| `cosmic/string.tl:251` (pad_left) | 0.9487 | `cosmic/string.tl:270` |
| `cosmic/string.tl:270` (pad_right) | 0.9487 | `cosmic/string.tl:251` |
| `cosmic/fs/dir.tl:72` (stat) | 0.8333 | `cosmic/fs/dir.tl:86` |
| `cosmic/fs/dir.tl:86` (stat_link) | 0.8333 | `cosmic/fs/dir.tl:72` |
| `cosmic/proc/rusage.tl:82` (getpriority) | 0.7556 | `cosmic/proc/rusage.tl:95` |
| `cosmic/proc/rusage.tl:95` (setpriority) | 0.7556 | `cosmic/proc/rusage.tl:82` |

CONTROL blocks:

| block | Jaccard | closest other |
|---|---|---|
| `cosmic/fs/dir.tl:113` (make_dir) | **0.8000** | `cosmic/fs/dir.tl:128` |
| `cosmic/fs/dir.tl:128` (make_dirs) | **0.8000** | `cosmic/fs/dir.tl:113` |
| `cosmic/check.tl:56` (not_equal) | 0.6780 | `cosmic/check.tl:77` |
| `cosmic/check.tl:77` (equal) | 0.6780 | `cosmic/check.tl:56` |
| `cosmic/signal.tl:149` (kill) | 0.7586 | `cosmic/signal.tl:162` |
| `cosmic/signal.tl:162` (killpg) | 0.7586 | `cosmic/signal.tl:149` |
| `cosmic/time.tl:273` (format_date) | **0.8000** | `cosmic/time.tl:299` |
| `cosmic/time.tl:299` (format_iso8601) | **0.8000** | `cosmic/time.tl:273` |
| `cosmic/codec.tl:72` (decode_base64) | 0.7143 | `cosmic/codec.tl:102` |
| `cosmic/codec.tl:102` (decode_base64url) | 0.7143 | `cosmic/codec.tl:72` |
| `cosmic/proc/rusage.tl:36` (getrlimit) | 0.5476 | `cosmic/proc/rusage.tl:50` |
| `cosmic/proc/rusage.tl:50` (setrlimit) | 0.5476 | `cosmic/proc/rusage.tl:36` |
| `cosmic/_teal_engine.tl:187` (process_source) | 0.6364 | `cosmic/_teal_engine.tl:265` |
| `cosmic/_teal_engine.tl:265` (process_file) | 0.6364 | `cosmic/_teal_engine.tl:187` |
| `cosmic/fs/ops.tl:401` (statfs) | 0.6562 | `cosmic/fs/ops.tl:414` |
| `cosmic/fs/ops.tl:414` (statfs_fd) | 0.6562 | `cosmic/fs/ops.tl:401` |
| `cosmic/sandbox/unveil.tl:54` | 0.7636 | `cosmic/sandbox/pledge.tl:72` |
| `cosmic/sandbox/pledge.tl:72` | 0.7636 | `cosmic/sandbox/unveil.tl:54` |
| `cosmic/fetch/verbs_test.tl:42` | 0.7000 | `cosmic/fetch/init_test.tl:30` |
| `cosmic/fetch/init_test.tl:30` | 0.7000 | `cosmic/fetch/verbs_test.tl:42` |
| `_perf/gate.tl:172` | 0.7000 | `_perf/gate.tl:333` |
| `_perf/gate.tl:333` | 0.7000 | `_perf/gate.tl:172` |
| `_tool/example.tl:201` | **0.8000** | `_tool/benchmark.tl:228` |
| `_tool/benchmark.tl:228` | **0.8000** | `_tool/example.tl:201` |
| `_make/policy_test.tl:124` | 0.7143 | `_tool/coverage/baseline_test.tl:27` |

**Signal B: worst TRUE = 0.6667 (`_make/readstamp.tl:65`), best CONTROL = 0.8000
(three-way tie: `fs/dir.tl` make_dir/make_dirs, `time.tl` format_date/format_iso8601,
`_tool/example.tl`/`_tool/benchmark.tl`) → margin = −0.1333. FAILS**, less decisively
than round 1's reported −0.3011 (the corrected fixture removes `user.tl`'s
`setresuid`/`setresgid` 0.9677 from CONTROL, which was round 1's cited lead failure
example — that pair is legitimately TRUE and its 0.9677 now sits among the TRUE rows,
not against them), but the margin is still solidly negative: three unrelated CONTROL
pairs independently reach 0.80, above the weakest TRUE near-duplicate at 0.6667.

**Decision (Change step 4/5), re-derived from the corrected fixture: neither signal
clears the required 0.10 margin, and both margins are still negative.** Signal A's
margin moved from −0.0890 to −0.2212 (more decisive); Signal B's moved from −0.3011 to
−0.1333 (less decisive, but still a clear fail). The corrected fixture changes the
supporting evidence and the exact numbers, not the verdict. Per step 5, the line ends
here: the exact-duplicate gate remains the whole enforcement for prose; no
`_tool/prose_similar.tl` / `_tool/prose_similar_test.tl` follow-up is warranted, and
none is filed. Recommend closing this item with this record as its final state.

Implementation notes for anyone attempting a different signal later: (1) the block
extraction above (doc-comment paragraphs split on a blank `---` line; markdown
paragraphs split on blank lines) is a reasonable approximation, not the sibling gate's
exact rule — re-derive candidate counts before trusting them precisely. (2) A naive
per-term-then-per-matching-doc Jaccard implementation is an O(fixture × terms × docs)
query explosion that runs for minutes without progress; batch each candidate's
shared-term lookup into one grouped `... WHERE term IN (...) GROUP BY doc` query and
precompute per-doc term counts with a single upfront `GROUP BY doc` pass first. (3) When
narrowing Jaccard's "best other" candidates with an FTS5 MATCH OR-query, `ORDER BY
bm25(blocks)` before applying `LIMIT` — an unordered MATCH with only a `LIMIT` returns
SQLite's default row order, which for a broad OR of common terms can fill the limit
window with arbitrary distant documents instead of the closest ones. This silently
produces near-random low Jaccard scores across the board that read as a signal failure
but are actually a candidate-selection bug (caught and fixed in this round: an
unordered first pass gave every block a "best other" in an unrelated file at Jaccard
≈0.15–0.3, before adding the ORDER BY surfaced the real near-1.0 scores for exact and
near-exact pairs).

Two out-of-scope findings surfaced while building the fixture were filed as their own
items, both under this item's parent, both targeted at the sibling exact-duplicate
gate item («iltX_EM90»): «qcY1_cArl» (`CLAUDE.md`/`AGENTS.md`, a symlink pair, will read
as spurious 1.00-ratio self-duplicates to any scanner that doesn't dedupe by realpath)
and «LOP1_MhAs» (6+ `_eval/checks/*.tl` files share a verbatim, legitimate
interface-contract doc comment at bm25 ≈1.00–1.04 — a decision the exact gate needs
before day one; this round's `_eval/checks/multi-module-build.tl:39` row above found a
7th member, `_eval/checks/module-tests.tl:22`, sharing the same template). Neither is a
follow-up of THIS item's own signal research (both signals failed; no
`_tool/prose_similar.tl` is filed or warranted) — they are independent defects the
fixture-building process happened to surface.

## Non-goals

A gate. Semantic or vector similarity («Pszd_rIKz» records why not). Comment quality.
Board items (their own sweep is «va0I_6MWO»). The exact-duplicate gate, filed beside
this one, which lands regardless of this item's outcome.
