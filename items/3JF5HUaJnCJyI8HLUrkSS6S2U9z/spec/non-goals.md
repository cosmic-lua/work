- `depends_on` is not populated from prose, for any item. See step 4.
- No item's `## Acceptance` content is preserved in the tree, and no attempt is
  made to turn one into a test. D47 settles that: done is the repo's gate
  passing, and the text stays in history.
- Nothing is backdated. Every migration commit carries the run's own date.
- No lazy or partial migration, and no second pass. One transaction, one push;
  a rejected push is re-prepared against the refreshed tips, never applied
  halfway.
- The migration module is NOT retired here — `06-retire` removes it, the same
  way `3423bac6` removed its predecessor in its own change.
- Nothing reads the migration commit bodies back. `gitboard log` exists now
  (`grep -n 'name = "log"' _work/gitcommands.tl`) but renders an item's own
  note entries, not arbitrary commit bodies, and this item does not extend it:
  the bodies are `git log` output, and a renderer for them is unbuilt work this
  chain does not cover.
