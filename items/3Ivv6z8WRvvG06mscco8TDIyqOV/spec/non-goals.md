- Not re-opening `3IvOz0wC`'s own scope (which files are instrumented,
  the collector's shape, the BUILD.mk wiring) — that item stands as
  built; this is a follow-on stabilization of one file's measurement.
- Not a general audit of test determinism across the suite — scoped to
  `lfetch.c`'s line coverage specifically, the one file this
  investigation found varying.
- Not assuming a fixed number of local reproduction runs proves
  stability — CI's own run environment demonstrably samples a wider
  variance than a local loop did; treat a local-only reproduction
  attempt that stays inside 586-592 as inconclusive, not as
  confirmation the floor holds.
