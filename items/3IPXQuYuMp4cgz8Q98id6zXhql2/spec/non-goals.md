- **Do not close a site with a cast.** `as` moves the lie from the type
  to a comment; every cast added here would land in
  `_build/casts_baseline.tl` and be someone else's slice.
- **Do not close a site with `check.must`.** It throws; AGENTS.md
  forbids it in library code.
- **No checker change.** The four narrowing rules are a separate item;
  this one is edits at sites.
- **Do not widen a return type to make a site compile.** Pushing the
  union one caller further out is not progress.
