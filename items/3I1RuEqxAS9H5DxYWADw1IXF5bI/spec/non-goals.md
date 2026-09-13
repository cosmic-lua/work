- **`fs.find` / `fs.find_iter` / `fs.find_info` / `fs.visit` are not
  in scope.** The finding's proposed trigger names `fs.glob`, `fs.walk`
  and `fs.ls` as illustrative examples; `fs.walk` and `fs.ls` do not
  exist in the `cosmic.fs` API (the real names are `fs.glob`, `fs.find`,
  `fs.find_iter`, `fs.find_info`, `fs.visit`). Measured just now: 16
  `*_test.tl` files call one of `fs.find`/`fs.find_iter`/`fs.find_info`/
  `fs.visit` with no `--- reads:` declaration, and all but one or two
  of them enumerate a fixture directory the test itself constructs
  (`TEST_TMPDIR`, a `temp_dir()`/`temp_file()` result) rather than the
  project tree — flagging all of them would be false-positive noise on
  a scale this slice has not audited file-by-file. Only `fs.glob` was
  audited (2 callers total, both handled: one allowlisted, one already
  declares). Widening the trigger to the other four primitives is
  follow-up work, one primitive at a time, each needing the same
  false-positive audit this slice did for `fs.glob`.
- **The "computed `require`" leg of the finding's proposed trigger is
  out of scope.** A syntactic scan for `require` calls whose target
  isn't a string literal was measured against every `*_test.tl` file:
  87 non-literal `require` occurrences across 40+ files, the large
  majority prose mentions or deliberate tests of the require machinery
  itself (`cosmic/searcher_test.tl`, `cosmic/searcher_tree_test.tl`,
  `cosmic/tl_loader_test.tl`) rather than instances of this bug class.
  Getting that trigger's precision right needs its own false-positive
  audit and its own allowlist design — a second, independent detection
  strategy, not a one-line addition to this slice.
- **`_make/pin_test.tl` is a separate, already-measured instance of
  this same bug class** (`fs.find("_make", {glob = "*.tl"})`, no
  `--- reads:`) and **`_eval/stage_test.tl` and `_make/fixpoint_test.tl`
  enumerate non-fixture directories via `fs.find`/`fs.visit`** with no
  declaration either. None of these call `fs.glob`, so this slice's
  lint does not touch them and they are not part of its Acceptance.
  File them as separate findings if not already tracked — do not fix
  them here.
- **No change to `#1178` or `#1156`'s work.** Both are landed (see
  Enablement) — this slice does not touch `_make/imports.tl`'s grammar
  or the D18 env-stamp mechanism, only adds a lint rule that reads
  `reads_scan`'s existing output.
- **No dynamic/runtime inference of reads** (the finding's "stronger,
  much more machinery" alternative: tracing what a test process
  actually `open()`s at runtime and diffing that against its
  declaration). Rejected for this slice: it needs a new collection
  mechanism (an strace-like or fd-tracing harness across every test
  process, cross-platform under Cosmopolitan), a place to store and
  compare the trace, and a decision about what a false-negative trace
  (a path opened only on one branch) means for the gate — three
  open designs where the syntactic rule has zero. It is strictly
  stronger (would also catch `fs.find`/`fs.visit`/computed-require
  cases with no per-primitive audit) and worth a dedicated enablement
  item once the syntactic rule's false-positive experience says the
  cheap version isn't enough; it is not this slice.
