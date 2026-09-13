- **Close no cast.** `git diff --name-only origin/main` names exactly
  `docs/design/casts.md` and `docs/design/cast-sites.tsv`. No `.tl` is
  edited, so `_build/casts_baseline.tl`, `.cosmic-coverage` and
  `_build/public_surface_baseline.tl` are unmoved by construction. A
  cast that is obviously removable is recorded as such in its class's
  verdict and left in place.
- **Do not touch `docs/goals.md`.** G3's prose, its measurement and
  its win condition are unmoved. An outcome changes by PR to
  goals.md, owned by the goal owner; this slice supplies the evidence
  and mints the item, and states the question in `## The floor`
  without answering it.
- **Do not touch `AGENTS.md`.** The narrowing doctrine is unmoved.
- **Do not write a decision record.** No file under `docs/decisions/`
  is added or edited — a census settles no tradeoff.
- **Do not add a `` Measured against `<sha>` `` line to `casts.md`.**
  It would switch the citation check to snapshot mode and stop the
  line numbers being verified. The TSV is the snapshot; the document
  is live.
- **No ```` ```teal ```` fences** in either new or edited prose —
  `_build/snippets_test.tl` holds them to the formatter and the
  checker, and a census quotes fragments that do not compile alone.
- **Do not commit the extractor script**, and do not add a new gate,
  lint, or committed tool. If the classification wants one, it is a
  minted item, not this diff.
- **Do not touch `3p/tl/`, `_types/`, or anything in
  `whilp/cosmopolitan`.** Naming a needed upstream fix in a verdict is
  the deliverable; making one is not.
- **Do not re-mint work an open item already covers** — `3IQtewgN`,
  `3ISJHfNY`, `3IOK2cxG`, `3IOmhR2S`, `3IQCrJpB`.
