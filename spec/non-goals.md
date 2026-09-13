- Do not move `_build/nil_returns_baseline.tl` as part of this: neither defect
  reaches a committed file today (verified — the pre-fix and post-fix detectors
  produce byte-identical baselines), so a fix that moves the number means
  something else changed too.
