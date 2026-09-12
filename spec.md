## Goal

`skills/work/SKILL.md`'s bootstrap section tells every session to run
`bin/gitboard sync` to pick up the board's items before doing anything
else. `sync` is a deprecated no-op that never fetches, so a session
that only has a `../work` sibling clone (no `o/board`, and no prior
fetch of the `items/*`/`board/*` refs) follows the doc exactly and
then sees an apparently empty board — `show`/`fsck` both report 0
items — with nothing in the doc explaining why or what to run instead.

## Evidence

`skills/work/SKILL.md:34-37`:

```
git clone https://github.com/cosmic-lua/work o/board   # only when no sibling
bin/gitboard sync                                       # every session
```

`sync`'s own help text (`bin/gitboard help sync`), current tree:

```
usage: gitboard sync [options]

deprecated: use refresh. This compatibility alias never fetches or performs provider operations.
```

Reproduced 2026-09-12 against a fresh `../work` sibling clone that had
never fetched the item namespace (only `main` and the session branch
present locally):

```
$ bin/gitboard sync
Downloading pinned gitboard...
gitboard-sync: deprecated; use `gitboard refresh`
git fetch --atomic --prune origin '+refs/heads/items/*:refs/remotes/origin/items/*' '+refs/heads/ended/*:refs/remotes/origin/ended/*' '+refs/heads/board/*:refs/remotes/origin/board/*' '+refs/heads/claim-batches/*:refs/remotes/origin/claim-batches/*'
gitboard-refresh: confirmed=0 pending=0 lost-race=0 expired=0; cache rebuilt; fetched refs were not changed

$ bin/gitboard show
doing  0
todo   0 (0 pullable)
triage 0
gitboard-show: doing 0

$ bin/gitboard fsck
gitboard-fsck: ok (0 items)
```

`sync` prints the fetch command as a dry run (this is `refresh`
without `--execute` under the hood — `help refresh`: "Without
--execute, prints the exact fetch command but does not run it") and
never executes it, so the local remote-tracking refs stay exactly as
the clone left them. Running the identical printed `git fetch` line
by hand (or `bin/gitboard refresh --execute`) is what actually
populates the refs — after that, `show`/`fsck` report the real board
(199 todo items at the time of this reproduction).

`sync` used to be a real fetch verb; it was turned into a no-op
compatibility alias in `_work/gitcommands.tl`/`_work/gitboard.tl` by
cosmic-lua/work#90 ("Redesign gitboard around caller-owned Git
transport"), and `skills/work/SKILL.md`'s bootstrap line was never
updated to match.

## Change

`skills/work/SKILL.md:34-37` (cosmic-lua/cosmic): replace the bootstrap
fetch line

```
bin/gitboard sync                                       # every session
```

with

```
bin/gitboard refresh --execute                          # every session — fetches; `sync` is a deprecated no-op
```

Also grep the rest of `skills/work/SKILL.md` and `skills/work/decompose.md`
for any other bare `gitboard sync` invocation and update each the same
way; `grep -n 'gitboard sync' skills/work/SKILL.md skills/work/decompose.md`
is the sweep to confirm none are left.

## Non-goals

Not changing `gitboard`'s own behavior (`sync`'s deprecation and
`refresh`'s `--execute` gate are working as designed, per their own
help text) — this is a docs-only fix to the skill that bootstraps
sessions onto the board.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.
