Three parts: the mechanism, the split, the tests.

### `_make/patch.tl` — a patch is one file or a directory of them

1. `of_pin` becomes `paths_of_pin(pin_source): {string} | nil` (rename
   both fetch.tl call sites): when `<stem>_patch.tl` is a file, return
   `{that path}`; else when `<stem>_patch/` is a directory, return its
   `*.tl` files sorted by name (via `cosmic.fs` listing); else nil.
   When BOTH exist, this is an error the caller must surface: return
   the list with the single file first is WRONG — instead add a second
   return, `paths_of_pin(): {string} | nil, string`, and make the
   both-forms case `nil, "<stem>_patch.tl and <stem>_patch/ both
   exist; keep exactly one"`. An empty directory returns
   `nil, "<dir>: a patch directory with no *.tl entries is one to
   delete"`.
2. `read` keeps its one-file signature. Add
   `read_all(paths: {string}): {Edit} | nil, string`: call `read` on
   each path, concatenate, and refuse a duplicate entry NAME across
   files naming both paths — one namespace, whatever the file layout.
   Keep the merged list in sorted-name order across the whole set, as
   `read` sorts today, so apply order is unchanged by the split.
3. Update the module header: the patch beside a pin is
   `<stem>_patch.tl`, or, when the entry set outgrows the 500-line
   cap, a `<stem>_patch/` directory whose `*.tl` files hold the
   entries — same format per file, one shared entry namespace,
   capacity by splitting rather than by a cap exemption.

### `_make/fetch.tl` — the two callers

`patch_of` (`:107`) and `repair` (`:265`) call `paths_of_pin` and
`read_all`, propagating the new error return. The archive-pin guard
(`:111-114`) is unchanged and applies to the whole set.

### The split

Create `3p/tl/tl_patch/ast_cache.tl` (the five `ast-cache-*` entries,
today's lines 24–172, byte-identical) and `3p/tl/tl_patch/narrow.tl`
(the fifteen `narrow-*` entries, lines 173–499, byte-identical), each
opening with the header lines that describe its own group plus the
shared two: the pointer to `_make/patch.tl` as the mechanism and the
carried-not-forked paragraph (anchor must match exactly once; a pin
bump that moves the code fails the fetch loudly). Delete
`3p/tl/tl_patch.tl`. Entry text is MOVED, never edited: find/replace
bodies byte-identical, which the oracle below checks better than any
diff read.

### `_make/patch_test.tl` — the new seams

Following the file's existing fixture style: a directory patch
resolves and merges (two files, entries from both applied); file and
directory together is refused with the message above; an empty
directory is refused; a duplicate entry name across two files is
refused naming both; a single-file patch still resolves exactly as
before (the regression pin for every other pin in every project).

### Ratchets

`bin/cosmic --make coverage --baseline` if the coverage gate asks
(two new tree files under `3p/tl/tl_patch/`, one deleted); any other
ratchet, run exactly the regen command its failure message prints and
commit the result.
