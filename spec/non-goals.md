**Do not delete any of the 5 casts in this PR.** CLAUDE.md's cold-build
rule: a new patch entry is exactly "a source that needs the tree's own
checker" — `_build/coldbuild_test.tl` type-checks generation 1 with
`bin/cosmic.pin`'s CURRENT release checker, which does not carry this
new entry yet, so code relying on it fails only a cold build. Land the
patch and its canary first; deleting the 5 casts is separate follow-on
work that must wait for a `bin/cosmic.pin` bump to a release built from
a tree carrying this patch (a release cut after this PR merges,
pinned in its own item) and, when filed, must carry a `blocked_by`
edge on that pin-bump item.
