In whichever `_work/brieftext*.tl` file contains the line "a main-repo
PR lands by enabling auto-merge (squash), never by merging directly.",
replace it with the two-branch rule `_work/doctrine.tl` already states:
a PR against `main` (or whatever the item's own `base` field says other
than `board`) lands via auto-merge; a PR against `board` merges
directly. The brief already has the item's `base` available when it is
filled (it is printed in `gitboard show`'s header and used to compose
step 8's "Open a PR from BRANCH to <base>" instruction in the builder
brief) — thread the same value into the review brief so the "accept"
instruction names the correct landing method for THIS item without the
reviewer having to guess or hit the auto-merge failure first.

`_work/brief_test.tl` (or `brieftext_test.tl`/`brieftext_review_test.tl`,
wherever the existing `Board:`-line-style pins for this template live):
one fixture item with `base: board` asserts the emitted review brief's
accept instruction says "merges directly"; one with `base: main` (or any
non-`board` value) asserts it says "enabling auto-merge".
