## Evidence

`bin/gitboard` (cosmic-lua/cosmic) picks the board with one line —
`grep -n 'GITBOARD_DIR' bin/gitboard` → 99
`GITBOARD_DIR="${GITBOARD_DIR:-${ROOT}/o/board}"` — while the `work`
skill's bootstrap (`skills/work/SKILL.md:33-42`) tells every session to
detect a sibling `../work` clone whose origin is cosmic-lua/work and
export `GITBOARD_DIR` to it by hand, in shell, before any verb. Every
brief this pass carried that export as prose; the PR 1759 rework
builder (2026-09-06) missed it, ran `bin/gitboard init` under
`/home/user/cosmic`, got a dead local-only board at `o/board`, and
spent 4 calls finding the skill's snippet by grep. A second clone at
`o/board` beside the sibling is also how two boards diverge in one
container.

`ls -d /home/user/work /home/user/cosmic/o/board` → both exist here.

## Change

`bin/gitboard`: when `GITBOARD_DIR` is unset, before defaulting to
`${ROOT}/o/board`, try the sibling `${ROOT}/../work`: if it is a
directory whose `git -C … remote get-url origin` prints a URL ending
in `cosmic-lua/work` or `cosmic-lua/work.git`, export that path
instead. One `if` block at line 99 in POSIX sh (no bashisms, the file
is `#!/bin/sh`), and a comment above it naming the skill's snippet as
the rule this now carries. `skills/work/SKILL.md:33-42`: replace the
shell snippet with the sentence "bin/gitboard prefers a sibling
`../work` clone of cosmic-lua/work over `o/board`; clone into
`o/board` only when no sibling exists", keeping the `sync` line.

Test: `_cli/gitboard_root_test.tl` (new, ≤ 60 lines) — under
`TEST_TMPDIR`, a fake `ROOT` with a copy of `bin/gitboard` and a
sibling `work` git repo whose origin is
`https://github.com/cosmic-lua/work`, and a stub `BOOTSTRAP` that
prints `$GITBOARD_DIR`; running the script prints the sibling path;
with the sibling's origin set to another URL it prints
`<ROOT>/o/board`; with `GITBOARD_DIR` exported it prints that. The
stub is reached by pre-placing the bootstrap file and its `.pin` so
`ensure_bootstrap` downloads nothing (read `bin/gitboard:60-96` for
the exact paths it checks).

## Non-goals

No change to how `bin/gitboard` fetches or verifies the pinned
release, no change to `gitboard init`, no board-side change in
cosmic-lua/work.

## Access

None at build time: `cosmic-lua/work` appears only as the fixture
origin URL string the test sets on a throwaway local repo (`git remote
add origin https://github.com/cosmic-lua/work`), matched by
`bin/gitboard`'s suffix check and never fetched.
