Rewrite both header doc comments to describe only the mechanism that
now exists: `_build/casts_kinds.tl`'s header drops the shrink-ceiling/
delete-at-zero description of `sites`, since the field is gone; `_build/
casts_test.tl`'s header drops the "no kind exceeds its ceiling"/"every
kind has at least one site" bullets, describing only the remaining
exactly-one-kind classification check. `grep -c sites
_build/casts_kinds.tl` should return 0 once this lands, matching what
#1793's own spec expected.
