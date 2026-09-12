## Evidence

`_work.repository_map` resolves an item's repository to the WRONG local
checkout, and two consumers report confidently wrong things as a result.
Reproduced against a session where the map is configured correctly:

    $ git -C /home/user/work config --local --get-all gitboard.repository
    cosmic-lua/work=/home/user/work
    cosmic-lua/cosmic=/home/user/cosmic

**Consumer 1 — the spec bar reports a present path as absent.**
`«tGkR_31q4»`'s `## Change` names `_work/ghwrite_test.tl`; its `repo` is
`cosmic-lua/work`:

    $ ls -la /home/user/work/_work/ghwrite_test.tl
    -rw-r--r-- 1 root root 17876 ... /home/user/work/_work/ghwrite_test.tl
    $ gitboard show tGkR_31q4 --dir /home/user/work | grep '^absent'
    absent: `_work/ghwrite_test.tl` does not exist in the tree

The file is present at the item's recorded `claim base`, at `origin/main`,
and in that checkout's working tree — no reading of "the tree" makes the
line true. `«ugaS_0KMn»` draws the same line for `_work/ghland.tl`.

**Consumer 2 — the review brief sends the reviewer to another
repository.** `gitboard brief review tGkR_31q4` (item repo
`cosmic-lua/work`) renders:

    Read the diff with `git fetch origin <branch>` and `git show
    <head>:<path>` in the product checkout at `/home/user/cosmic`

and every verdict line it prints carries `--repo-dir /home/user/cosmic`.
That is `cosmic-lua/cosmic`'s tree. It has no `_work/` directory at all,
so a reviewer following the brief literally cannot find one file of the
diff. Caught by hand this session; a reviewer who trusted it would have
burned a round discovering the tree was wrong.

**Both point at the same resolution.** `/home/user/cosmic` is where the
`bin/gitboard` trust root that ran the command lives — not the checkout
the map names for `cosmic-lua/work`. Every observed wrong answer is that
directory, and `_work/ghwrite_test.tl` and `_work/ghland.tl` are both
genuinely missing from it, which is exactly what the `absent:` lines say.
The answer does not change with the process's cwd (`/home/user/work` and
`/home/user/cosmic` give the same output), so it is not a cwd fallback —
the lookup itself is returning the running tool's own checkout.

`«66ad_YWIV»` ("spec bar resolves paths against item's repo, not running
checkout") fixed this for one call site. Two more have it, one of them a
brief that directs a fresh-context agent at the wrong repository.

## Change

Find why `_work.repository_map`'s lookup returns the running tool's
checkout for an item whose repo is mapped elsewhere, and fix it at the
lookup so every caller gets the same corrected answer. Confirm both
symptoms above go away, and say in the PR body which call sites were
affected — a fix that only repairs `show` leaves the brief defect live.

Resolve the spec bar's path check against the item's repository at a
known commit — its recorded `claim base` when it has one, else the
repo's default-branch tip — rather than against a working tree, so the
answer stops depending on which branch a checkout is parked on.

Add cases: an item whose repo maps to a checkout other than the running
one resolves to the mapped checkout; a path present at the resolved
commit but absent from a checkout's working tree is NOT reported absent;
a path genuinely absent at that commit still is; and a review brief for
an item in a non-running repository names that repository's checkout in
both its prose and its `--repo-dir` lines.

## Non-goals

Not changing the `gitboard.repository` config format, not changing which
sections of a spec contribute paths, and not changing the
`tight:`/`not checked` wording. Not making any check reach the network:
it resolves through a local checkout of the item's repo, or reports
`not checked` as it does today when there is none.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
