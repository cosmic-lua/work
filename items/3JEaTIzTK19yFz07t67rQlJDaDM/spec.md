## Evidence

Every builder brief names a branch that does not exist. Reproduced
2026-09-12 while building `BM00_etFW`; the same wrong shape appears in every
brief generated this session (`Kfl8_Jtao`, `66ad_YWIV`, `U8Qv_yhHw`,
`eB88_K0hY`, `BM00_etFW`).

`gitboard brief builder BM00_etFW` rendered:

    It is on branch `3JEXrnwp`, branched from product commit recorded by
    the claim.

`3JEXrnwp` is the item id's leading 8 characters, not a branch. In the
worktree the brief itself points at:

    $ git rev-parse --abbrev-ref HEAD
    work/BM00etFW/e2cfd4b32e5d
    $ git rev-parse --verify 3JEXrnwp
    fatal: Needed a single revision

The real branch is the one `gitboard worktree` creates and prints on its own
verdict line (`work/<handle>/<claim>`, `help orchestrate`'s stated shape).
No work was lost in the observed case — the builder only noticed at the end,
because the brief also says to work in the directory, which is correct — but
a builder that acts on the sentence (`git checkout 3JEXrnwp`, or naming it in
a push) gets a refusal or a detached HEAD for a reason the brief itself
caused.

## Change

`_work/brieftext.tl`'s builder template (and any other kind whose body
carries this sentence): render the claim's actual branch — the same
`work/<handle>/<claim>` string `worktree` creates and `gitboard-worktree`'s
verdict line prints — instead of the item id's leading characters.

Add a case to the matching `*_test.tl` asserting the rendered brief names a
branch of the `work/<handle>/<claim>` shape, and specifically that it does
NOT name a bare id prefix — so this cannot regress into printing an
identifier that happens to look plausible.

## Non-goals

Not changing what `worktree` names the branch, and not changing the
"work exclusively inside that directory" instruction — the directory
sentence is correct today and is what builders actually act on.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
