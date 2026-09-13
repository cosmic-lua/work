- No new `_perf/bench/fs_bench.tl` scenario for the stat-touching path
  (`e:stat()` called on every entry). `fs_walk_tree`'s visitor reads
  only `e.path` and is the gate for the stat-free win this item
  targets; pricing the stat-touching −21% side with a companion
  scenario is real, independent work — a separate item, not folded in
  here.
- No rewrite of `cosmic/fs/find.tl`'s own traversal engine beyond
  `find_info`'s mechanical `Entry.stat` migration above — `find`/
  `find_iter`/`glob` already run their own d_type-based loop
  (`find.tl:151-255`) and are untouched by this item.
- No attempt to discover or migrate callers outside this repo — D41's
  consequences section records that cost; it is not this item's to
  close.
- `_tool/coverage/report.tl` (499 lines after the net −1 edit above)
  and `_make/artifact.tl` (500 lines after the net +1 edit above) land
  with one line or zero lines of headroom under the 500-line cap as a
  direct result of this migration — any future change to either file
  inherits that, and will need its own trim; that is a cost this item
  accepts, not a problem it solves.
