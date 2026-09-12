## Evidence

`gitboard brief review` computes its review range as a two-dot diff from
a recorded commit, not as the merge-base diff of the handover against the
item's base branch. When the branch has merged its base forward — which
the base-pinning discipline requires whenever a branch falls behind — the
range shows REVERSE diffs of commits the branch does not carry.

Three instances this session, all caught by hand before a reviewer acted
on them:

**1. A range whose base is not an ancestor at all.** `«UqZn_jV6U»`'s
brief said `Review 4854db04..df3ef453`. `4854db04` is PR #1842, NEWER than
the handover and not an ancestor of it:

    $ git merge-base --is-ancestor 4854db04 df3ef453; echo $?
    1
    $ git diff --stat 4854db04..df3ef453 | tail -1
    37 files changed, 200 insertions(+), 1879 deletions(-)

1879 deletions of unrelated files, including decision records the item
never touched. A reviewer working that range would have been reading a
fabrication.

**2. A two-dot range across a forward merge.** `«uOsC_KV6H»`'s re-review
brief said `6ed6b8da..a211b826`, where `6ed6b8da` is a main commit the
branch merged in:

    $ git diff --stat 6ed6b8da..a211b826 | tail -1
    28 files changed, 1822 insertions(+), 745 deletions(-)
    $ git diff --stat origin/main...a211b826 | tail -1
    21 files changed, 1810 insertions(+), 309 deletions(-)

Seven files and 436 deletions that are not the pull request's change.

**3. The same brief's `--repo-dir` named another repository** — that is
`«WsH8_pWpE»`, landed as #149 but not yet in the pinned release, so it
still reproduces.

The cost is not a wasted call. A review's whole value is that it is
adversarial about a specific diff; handing it a range that includes
reverse-diffs invites findings about deletions nobody made, and a
reviewer who trusts the brief spends its effort on fiction. Each instance
here needed the caller to notice and correct it before the review
started, which is exactly the check the brief exists to remove.

## Change

Compute a review's range as the merge-base diff between the handover
commit and the item's base branch — `git diff <base>...<head>`, three
dots — so a branch that merged its base forward is still reviewed on its
own change. Resolve `<base>` from the item's own `base` field when it has
one, falling back the way the briefs already resolve a default branch.

Refuse rather than render when the computed base is not an ancestor of
the handover: a range that cannot describe the change is worse than no
range, because it looks authoritative. Say what was expected and what was
found.

Add cases: a branch that merged its base forward reviews only its own
diff; a base that is not an ancestor of the head is refused, naming both;
and a simple branch with no forward merge is unchanged.

## Non-goals

Not changing the mechanical/full review split (`«qjz5_gybg»` owns that),
the `<PRODUCT_ROOT>` resolution (`«WsH8_pWpE»`, landed), or either review
script's text. Not changing what `take` records, and not fetching: the
brief resolves against refs the caller has already made local, as it does
today.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
