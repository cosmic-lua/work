## Evidence

`gitboard show` reports a spec-bar `absent:` line for a path that is
present. Two distinct cases, both reproducible today:

**A present file reported absent.** `«tGkR_31q4»`'s `## Change` names
`_work/ghwrite_test.tl`. The repo map resolves the item's repo to a real
checkout, and the file is there:

    $ git config --local --get-all gitboard.repository   # in /home/user/work
    cosmic-lua/work=/home/user/work
    $ ls -la /home/user/work/_work/ghwrite_test.tl
    -rw-r--r-- 1 root root 17876 ... /home/user/work/_work/ghwrite_test.tl
    $ gitboard show tGkR_31q4 --dir /home/user/work | grep '^absent'
    absent: `_work/ghwrite_test.tl` does not exist in the tree

The file is also present at every ref that matters — the item's own
recorded `claim base` (`614ce976`), `origin/main`, and that checkout's
`HEAD` — so no reading of "the tree" makes the line true.

**The check reads a working tree, not the item's repo at a commit.**
`«ugaS_0KMn»` draws `absent: _work/ghland.tl does not exist in the tree`.
There the file genuinely is missing from `/home/user/work`'s working
tree, and genuinely present at `origin/main`:

    $ git -C /home/user/work cat-file -e origin/main:_work/ghland.tl && echo PRESENT
    PRESENT
    $ ls /home/user/work/_work/ghland.tl
    ls: cannot access ...: No such file or directory

That checkout sits on an unrelated branch. Every builder brief already
says the board checkout "is the orchestrator's and is stale by
construction" — so resolving a spec's paths against its *working tree* is
reading exactly the tree the tool tells agents not to trust.

`«46lA_bIVt»` and `«BM00_etFW»` print no headroom line at all under the
same invocation, so the behaviour is not uniformly on or off either.

The cost is that the line is noise: an orchestrator pulling an item must
verify each `absent:` by hand before deciding whether the spec is stale
(done twice this session, ~4 tool calls each), and a line that is wrong
this often stops being read — which is worse, because a genuinely stale
spec path is exactly what the bar exists to catch.

`«66ad_YWIV»` ("spec bar resolves paths against item's repo, not running
checkout") fixed the resolution to go through the repo map. This is the
next layer: what it resolves *to*.

## Change

Make the headroom path check resolve against the item's repository at a
known commit rather than against whatever a checkout's working tree
happens to hold — the item's recorded `claim base` when it has one, else
the repo's default branch tip — so the answer does not depend on which
branch an unrelated checkout is parked on.

Then find and fix the case A false positive: a path present in the
resolved checkout at every ref, still reported absent. Narrow it to the
actual cause (token extraction, path joining, or the presence probe)
before changing anything, and say in the PR body which it was — the two
cases above may or may not share a root.

Add cases covering both: a path present at the resolved commit but absent
from a checkout's working tree must NOT be reported absent, and a path
genuinely absent at that commit must still be reported. The two are close
enough that a fix keyed on the wrong side would pass one alone.

## Non-goals

Not changing which sections of a spec contribute paths, not changing the
`tight:`/`not checked` wording, and not touching `_work.repository_map`'s
lookup — `«66ad_YWIV»` settled that. Not making the check reach the
network: it resolves through a local checkout of the item's repo, or it
reports `not checked` as it does today when there is none.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
