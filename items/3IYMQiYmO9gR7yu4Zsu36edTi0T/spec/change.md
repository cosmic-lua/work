This item is a container; its deliverable is children, not a diff.
File five items under G3, one per class above, each spec carrying:
that class's rows verbatim (re-run the `awk` at filing time), the
mechanism named above, the `_build/casts_baseline.tl` rows it lowers,
the tsv reconcile step, and — when the class empties — deletion of its
`###` heading from `docs/design/casts.md` (precedent
`git show cf416d85 -- docs/design/casts.md | grep '^-###'`). The two
UPSTREAM children are checker-patch items: their spec names the
`3p/tl/tl_patch/` entry shape (`narrow.tl:28-32`: named `find`/
`replace` with a `note`), the upstream tl issue to open (D21's
maturity clause), and a `blocks:` on a `bin/cosmic.pin` bump before
any cast is deleted (CLAUDE.md's cold-build rule). Then end this item
`completed`.

Do not re-mint what `3IQtewgN`, `3ISJHfNY`, `3IOK2cxG`, `3IOmhR2S`,
`3IQCrJpB`, `casts-map-view` or `respec 6sv6` already cover.
