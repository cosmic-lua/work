- **Do not touch `docs/design/cast-legality.md`.** It documents itself
  as a snapshot ("Measured against `e0580f41`... The counts are a
  snapshot... re-running the Method command against a later tree is
  how a later pass re-derives them") and nothing gates it against the
  tree. Its `proved-value narrowing` row goes stale by design, same as
  every other row will as sibling closure items land.
- **Do not touch `docs/goals.md`** or the G3 floor wording — that is a
  separate decision (`ke6byr5h`).
- **Do not reclassify** any site, and do not touch any other class's
  heading, exemplar, or sites in `docs/design/casts.md` /
  `docs/design/cast-sites.tsv`.
- **Do not modify `_build/casts_test.tl` or `_build/cast_sites_test.tl`**
  — the ratchets themselves are out of scope; this change only feeds
  them a smaller tree.
- **Do not widen `_make/runverb.tl`'s `resolve` signature** or touch
  `_make/law.tl` — see the note in section 4.
