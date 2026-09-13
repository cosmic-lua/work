- No change to any other binding, including `unix.tiocgwinsz` and
  `unix.openpty`, which have the identical pattern and independent
  sibling captures.
- No change to cosmic's `cosmic/fd.tl`/`cosmic/quicksand/*` call
  sites in this PR — this is a BEHAVIOR change (the success shape
  moves from two positional integers to one table), so every
  positional destructuring of `unix.pipe()`'s success values breaks
  the moment this lands. Retiring those six call sites' destructuring
  for `.reader`/`.writer` field access is a separate, cosmic-side
  consumption slice, blocked on this capture landing — do not fold it
  into this diff, and do not bump the cosmos pin here.
