Append one paragraph to the shared header block of each of the three
`3p/tl/tl_patch/*.tl` files — `ast_cache.tl`, `closure.tl`, `narrow.tl` —
as the LAST lines of the header, directly above that file's `return {`
line, byte-identical in all three. Exactly these seven lines, verbatim
(a bare `--` separator, then six comment lines):

    --
    -- Probing an entry: reverse it with `_make.patch`'s `reverse`, which loads
    -- the de-patched copy into `package.loaded`, the table `require` reads
    -- before any searcher. A modified copy placed on `package.path` is ignored
    -- instead: the binary's own `/zip` searcher outranks the file searcher, so
    -- such a probe measures the shipped checker and reports a confident wrong
    -- answer with nothing logged.

Nothing else changes in those files, and no other file is touched.

Placement is settled, not open. The three files ALREADY carry a
byte-identical two-paragraph tail (`The mechanism is _make/patch.tl…` and
`Carried, not forked:…`) — verified 2026-08-28:

    $ for f in 3p/tl/tl_patch/*.tl; do \
        awk '/^-- The mechanism is _make\/patch.tl/,/^-- until the patch is re-audited/' \
        "$f" | md5sum; done
    e873abccfdd1d9688699611cb3be007b  -
    e873abccfdd1d9688699611cb3be007b  -
    e873abccfdd1d9688699611cb3be007b  -

so a third replicated paragraph is the file set's existing convention
rather than new duplication, and the replication is mechanically
checkable (Acceptance asserts one occurrence per file, three in total,
and that the extended block stays byte-identical). Duplication is the
right answer here because the alternative — one canonical copy the three
files point at — is the shape that already failed: `_make/patch.tl` IS
that canonical copy, and a session editing an entry never opens it.

Measured headroom against the 500-line cap, 2026-08-28:

    $ wc -l 3p/tl/tl_patch/*.tl
      168 3p/tl/tl_patch/ast_cache.tl
      348 3p/tl/tl_patch/closure.tl
      403 3p/tl/tl_patch/narrow.tl

seven lines each takes them to 175, 355 and 410.
