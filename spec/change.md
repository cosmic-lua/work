Reword `_work/brieftext.tl:54-56` (`BUILDER` step 1) to defer instead of
assert: a builder checks the repo's own `AGENTS.md` (or equivalent) for
a file-length convention and applies whatever it finds — consistent
with how gitboard already treats every other repo convention. This item
has no dependency on «oJ31_ppvR»'s resolver or its sibling wiring items,
and none on the manifest-field alternative this item originally
weighed — the parent outcome no longer carries a manifest format, so
deferring to `AGENTS.md` is the one approach here, not a choice between
two.

`_work/brieftext_test.tl`'s existing cap-related assertions get updated
to match, proven against a fixture repo with a stated cap different from
500.
