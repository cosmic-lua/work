- Does not itself propose a fix — staging behind an
  `--include-dir`-propagation change (env var, a wider default,
  changing what `main.tl` requires unconditionally, or something else)
  is a real design decision for whoever picks this up, not this
  capture's job.
- Does not re-verify `3IkSSqvH`'s own closure-compile fix, which this
  item's own Evidence confirms still holds (`cosmic/fd.tl`,
  `cosmic/fs/dir.tl` compile cleanly in the closure pass on this same
  tree).
- Does not itself adapt or revert any wrapper; `3IkMf7BY`'s branch
  (`cosmic-pin-bump-3IkMf7BY`, pushed) carries the complete, warm-CI-green
  adaptation as-is, blocked on this item.
