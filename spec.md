## Evidence

`cosmic-lua/cosmic` carries an orphan branch named `board` (`git ls-remote
--heads origin board` → `561af735...`) whose tree (`README.md`, `_work/`,
`bin/`, `cmd/`, `items/`, `lanes_state.tl`) is near-identical in shape and
self-description to `cosmic-lua/work`'s `main` branch — but `cosmic-lua/work`
is the repository `bin/gitboard.pin` actually pins releases from (its own
comment: "Every push to main of cosmic-lua/work publishes a release") and
that this project's own bootstrap (`skills/work/SKILL.md`) clones as the
live state repository. Comparing the two trees directly:

    $ git clone --depth 1 --branch board https://github.com/cosmic-lua/cosmic board-src
    $ git clone --depth 1 https://github.com/cosmic-lua/work work-repo-check
    $ ls board-src/_work | wc -l; ls work-repo-check/_work | wc -l
    81
    111

`cosmic-lua/work`'s `_work/` carries an entire additional layer
(`cache.tl`, `cachedb.tl`, `cachequery.tl`, `index.tl`, `find.tl`,
`gitobj.tl`, `gitread.tl`, `gitreadmany.tl`, `gitwrite.tl`, `refs.tl`,
`itemtree.tl`, `fastimport.tl`) that `cosmic-lua/cosmic`'s `board` branch
does not have at all, and stores items as git refs
(`refs/heads/items/<ksuid>`, no `items/` directory — per
`work-repo-check/README.md`) rather than `board-src`'s file-based
`items/<ksuid>.tl` + `.md`. `board-src`'s last commit is a bare `compare`
board-state edge (`561af73 compare 3IsZSbG2 over 3IpN6oy9`) — not a source
change — and a shallow-history check found no recent `_work/*.tl` source
commits on it at all in this session's own probing.

Cost, this session (`/work 9 --routine`, 2026-09-04): 21 open items with
`_work/*.tl`-scoped specs had `target: cosmic-lua/cosmic@board` (17) or an
unset/wrong-default `target: cosmic-lua/cosmic` (4, silently resolving to
`main`, which has no `_work/` tree at all — a third, even more broken
outcome). One builder agent (`gj7P_Db0H`) fully implemented, gated green,
and opened a real PR (#1716) against `cosmic-lua/cosmic`'s `board`
branch — a PR that, however correct, could never ship, because releases
build from `cosmic-lua/work` alone. Closed after the fact. A second agent
(`4CTF_fCZV`) committed locally against the same stale branch before being
caught pre-push. A prior session (item `4URu_CfFY`'s own evidence, filed
2026-09-04 before this one) hit the identical stale-branch confusion
independently and only partially resolved it (repaired `base: board`
without ever considering `cosmic-lua/work` as the real target). All 21
items were repaired this session (`gitboard set ID --repo cosmic-lua/work
--base main`); this item is the systemic fix so a 22nd instance doesn't
recur.

## Change

Either (a) delete the `board` branch of `cosmic-lua/cosmic` outright (a
human call — this session did not do it, since a branch deletion on a
shared repo is exactly the kind of hard-to-reverse action that needs
explicit sign-off, not an orchestrator's own judgment) so `git show
origin/board:_work/gitgraph.tl`-style greps and old muscle-memory can no
longer resolve to it; or (b), if it must stay (e.g. for git-archaeology or
because something still reads it), add a one-line `README.md` at its root
stating plainly "SUPERSEDED — the gitboard tool's live source and state
are `cosmic-lua/work`; this branch is kept only for history" so the very
first thing a session or human lands on when it clones this branch
self-corrects instead of building against it. Whichever is chosen,
`_work/gitowner.tl` (or wherever `gitboard new`'s repo-acceptance list
lives): if `cosmic-lua/cosmic` remains an accepted `--repo` value at all,
its `board` base specifically should be refused with a message pointing
at `cosmic-lua/work` instead — mechanical prevention outranks a README a
session can still skip past.

## Non-goals

Not a fix for `4URu_CfFY`'s own still-open cross-repo split question
(the `_work/**` half now correctly targets `cosmic-lua/work`, but its
`skills/work/SKILL.md` half is a genuinely different repo/branch — that
item still needs its own refiner split, unrelated to which branch is
stale). Not a rewrite of every affected item's spec PROSE (many still say
"on the board branch" in their `## Evidence` text) — the `target` field
repair is the actionable fix; a builder's own step-1 re-measurement
against the real tree is what the standard build brief already requires
and catches any remaining stale wording.
