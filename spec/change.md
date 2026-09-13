Widen the receiving locals to `T | nil` (they are cleared on purpose)
or have the helpers return the cleared value's type honestly — pick
the shape the helper's callers already assume, one convention across
the eight files. `_perf/bench/*_bench.tl` and the two helpers only.
