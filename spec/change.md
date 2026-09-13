Correct the two comments so each describes what is actually there:
`_work/brieftmpl_source.tl`'s header giving the real reason for the split,
and `_work/brieftmpl_gen.tl`'s giving the real reason a declared-input
test was not used (the carve-out exists; the ferry file and the
verbs-without-tests gap are why it was not taken).

Record, where the generator's check is documented, the two facts a reader
needs to trust it: that it is sound in CI because `ci` runs before any
other generator-running verb there, and that a warm local checkout which
has already run such a verb will pass over committed drift.
