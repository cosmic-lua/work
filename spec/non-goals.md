- No change to `unix.Dir:fd()`'s actual return shape or behavior —
  documentation only.
- No change to `unix.Dir:tell()` — a lesser, similar note (its `|nil`
  has never been reachable since the file's initial import, but no doc
  comment claims otherwise for it, so there's no drift to correct).
- No required change to `cosmic/fs/dir.tl` — the defensive fallback is
  harmless and simplifying it is left to implementer's judgment, not
  gated by this capture's acceptance bar.
