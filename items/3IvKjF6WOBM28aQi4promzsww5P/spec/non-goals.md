No span/splice logic (depends on the walk item, kept separate), no
project-wide file traversal (the CLI item's job), no type-aware
matching (a real v2 needing `tl.check`'s typed env — out of scope for
the syntax-only matcher this item builds; note it as a clearly separate
future item if picked up later, don't fold it in here).
