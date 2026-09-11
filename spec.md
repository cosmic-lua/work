## Evidence

Nothing in a builder brief, `AGENTS.md`, or `gitboard help worktree`/`help
build` tells a builder agent that its own claimed worktree may be modified
by a process other than itself — specifically, by the orchestrator taking
over a stalled build (one that stopped its turn waiting on a background
shell command it lost track of, per the orchestrator's own established
recovery practice this session: check the worktree directly, finish the
run, commit if needed).

Reproduced concretely on 2026-09-11: a builder agent for item `3J8sbXOF`
stalled twice waiting on background `--make ci` runs it had started but
did not keep polling within its own turn. Each time, the orchestrator
intervened directly in the SAME worktree (`/home/user/wt/work/5PCVsHrL/...`)
while the agent's task was between turns: waiting for the live process,
running `bin/cosmic --fix`, merging `origin/main`, and (in the agent's own
final report, quoted verbatim) —

> during a later `--make ci` run, something outside my own tool calls
> executed `git merge origin/main` on this worktree's branch (visible in
> `git reflog` as `HEAD@{0}: merge origin/main`, author `Claude
> <noreply@anthropic.com>` ... I did not invoke this merge myself and could
> not find any code path in this repo's own `_make`/`_build`/`cmd` tooling
> that performs a `git merge` ... it appears to originate from something in
> the shared session/worktree environment

The agent then spent real investigation time (checking `.claude/settings.json`,
hooks, and `_make` sources) before concluding it was "environmental" and
resetting its own branch with `git reset --hard` back to its own single
commit — discarding the orchestrator's already-pushed-and-PR'd merge commit
from its LOCAL copy of the branch (harmless here only because the
orchestrator had already pushed that commit to origin before the agent's
reset touched its own local ref, so the remote/PR was unaffected — a
different interleaving could have raced a still-unpushed merge).

This is the second time this exact shape occurred this session (the first
being item `3J91Fp7o`'s builder, which stalled similarly and was recovered
the same way without incident because the orchestrator's edits there were
smaller).

## Change

Repo: `cosmic-lua/work`. Two files, both text-only: one paragraph added to
a template string constant, one test function that pins it. No verb's
behaviour changes.

### Measured during refinement (2026-09-11, at `098d7ca1`)

`wc -l _work/brieftext.tl _work/brieftext_test.tl`

```
  401 _work/brieftext.tl
  239 _work/brieftext_test.tl
  640 total
```

Both are far under the 500-line cap; no split seam is needed and none
should be made.

The builder template's `## Where to work` section, in full —
`sed -n '27,38p' _work/brieftext.tl`:

```
## Where to work

Your git worktree is already checked out at:
`<WORKTREE>`

It is on branch `<BRANCH>`, branched from product commit recorded by
the claim. Work exclusively inside that directory.
<PREPARATION>
The checkout that holds the board worktree (`<BOARD_DIR>/..`) is the
orchestrator's and is stale by construction; never read, grep or build
in it. Your worktree is the only tree.

```

(Line 37 is `in it. Your worktree is the only tree.`; line 38 is blank;
line 39 is `## The item`.)

Nothing anywhere in `_work/*.tl` tells an agent its worktree may be
touched by another process —
`grep -nE "reflog|another process|outside your own|did not (make|invoke)|stalled" _work/*.tl`:

```
_work/gitdraft.tl:204:  -- tracking-ref movement, reflog expiry, and aggressive GC.
_work/gitdraft_test.tl:101:  local gc = check.must(child.run({"git", "reflog", "expire", "--expire=now",
_work/gitdraft_test.tl:127:  local gc = check.must(child.run({"git", "reflog", "expire", "--expire=now",
_work/gitfsck_test.tl:281:--- The wrapper is installed by editing THIS process's own `PATH`
_work/health.tl:9:---                   than the lease is stalled, not in progress
_work/prepared.tl:120:  -- when another process replaces the staging ref while objects are loaded.
_work/prepared.tl:269:  -- Confirmation cleanup is cooperative: another process refreshing the same
_work/prepared_quarantine_test.tl:63:      {"git", "reflog", "expire", "--expire=now", "--all"},
_work/prepared_test.tl:150:  local gc = check.must(child.run({"git", "reflog", "expire", "--expire=now",
_work/publish.tl:209:--- binary installed" decision `iso8601_z` makes for the timestamp:
_work/publish.tl:270:--- a fact of the git binary installed rather than of the commits
```

Every hit is unrelated internals (git plumbing in `gitdraft`/`prepared`, a
lease-health comment). `_work/brieftext.tl` and `_work/doctrine.tl` do not
appear. The released help topics are silent too —
`bin/gitboard help build | grep -niE "worktree|orchestrator|merge"`:

```
21:   its claim, named `work/<handle>/<claim-root-short>`. `worktree ID` creates
33:6. Rejoin the loop. Never merge unreviewed work, and never accept
```

and `bin/gitboard help worktree | grep -niE "orchestrator|modif|edit"` prints
nothing (exit 1).

The fill grammar is `<UPPER_SNAKE>` — `grep -n '%u\[%u_\]' _work/brief.tl`
gives `59:  local out = text:gsub("<(%u[%u_]*)>", ...` and
`74:  for key in text:gmatch("<(%u[%u_]*)>") do`, and
`_work/brief_test.tl:160` asserts `"lowercase brackets are prose, not
placeholders"`. The text added below contains no angle brackets at all, so
it declares no new placeholder and `brief`'s unfilled-placeholder verdict
line is unchanged.

### 1. `_work/brieftext.tl` — add the warning to `BUILDER`

Inside the `BUILDER` template constant, after the existing line
`in it. Your worktree is the only tree.` (line 37) and its following blank
line, insert this paragraph followed by a blank line, so `## The item`
still begins the next section. Add it verbatim:

```
The worktree is yours to work in, but not yours alone: while your turn
is between tool calls the orchestrator may run commands in it, edit
files, commit, and push — most often to finish a build you left waiting
on a background command. Git history and file changes you did not make
are therefore expected, not a broken environment: a merge of
`origin/main`, a commit authored by someone other than you, a file
changed since your last edit. Never investigate one as an environment
bug, and never undo it — no `git reset --hard`, no `git revert`, no
force-push. Read what is there with `git log` and `git status`, build on
top of it, and name the commits that are not yours in your final report.
Avoid needing any of this by never ending a turn with a long command
still running in the background: poll it to completion inside the turn
that started it.
```

Touch no other template: `REWORK`, `RESEARCH`, `REFINE`, `DECOMPOSE` and
the two templates in `_work/brieftext_review.tl` stay exactly as they are.
Do not re-wrap or otherwise edit the three paragraphs already in
`## Where to work` — `_work/brief_test.tl`'s
`test_builder_brief_carries_the_item_and_names_the_rest` matches the
stale-board sentence through a flattened `stale_board_sentence(s)` helper,
and that sentence must survive byte-for-byte in substance.

### 2. `_work/brieftext_test.tl` — pin it

Append this test function to the end of the file, in the file's existing
style (a top-level `local function test_*`, enrolled by being defined —
this file has no self-calls). `BUILDER` at the top of that file is already
the whitespace-flattened template, so the needles below are the flattened
form of the paragraph above:

```teal
-- The orchestrator recovers a stalled build by working directly in the
-- builder's own worktree, so a builder that meets foreign history there
-- must neither investigate it as a broken environment nor undo it.
local function test_where_to_work_warns_the_worktree_is_shared()
  assert(BUILDER:find(
      "The worktree is yours to work in, but not yours alone: while "
      .. "your turn is between tool calls the orchestrator may run "
      .. "commands in it, edit files, commit, and push — most often to "
      .. "finish a build you left waiting on a background command.",
      1, true) ~= nil,
    "Where to work must say the orchestrator may work directly in the "
    .. "builder's own worktree between its turns")
  assert(BUILDER:find(
      "Never investigate one as an environment bug, and never undo it "
      .. "— no `git reset --hard`, no `git revert`, no force-push.",
      1, true) ~= nil,
    "Where to work must forbid investigating or undoing a change in "
    .. "the worktree the builder did not make")
end
```

Both needles use the em dash `—` (U+2014), the same character the template
paragraph uses; a hyphen there makes the find fail.

Verified during refinement that these two needles match the paragraph
above once flattened: a scratch script applying this file's own
`(s:gsub("%s+", " "))` to the paragraph and running both `find(n, 1, true)`
calls printed

```
needle1	true
needle2	true
```

so the pair is consistent as written; keep the paragraph and the needles
in sync if either is reworded.

### Tracking files

No committed tracking file changes shape. `.cosmic-coverage` rows are
source lines, not string bytes: `grep -n "brieftext" .cosmic-coverage`
gives `12:  ["_work/brieftext.tl"] = {["covered"] = 6, ["total"] = 10},`
(plus the `_friction` and `_review` rows) — the ten lines are the module's
`local`/record/return statements, and growing an existing `[[...]]`
constant adds none. `grep -c "_test.tl" .cosmic-coverage` prints `0`, so
the new test function adds no row either.

The gate is `bin/cosmic --make ci` at the repo root, per `README.md`.

## Non-goals

Not proposing that agents and the orchestrator never share a worktree, or
that the orchestrator stop taking over stalled builds directly — that
recovery path is working and fast. Not about the underlying cause of the
agent's own stall (losing track of a backgrounded long-running command),
which is a separate, already-observed pattern with its own mitigation
(never end a turn with a long command still running in the background).

Not the `build` or `orchestrate` doctrine topics in `_work/doctrine.tl`:
the item is about the brief a builder is handed, and a builder that read
the brief has no reason to run `gitboard help build`. Adding the same
warning there is a separate item if it is wanted at all — leave
`_work/doctrine.tl` untouched.

Not a mechanism that detects or prevents the foreign edit (a lock, a
lease check, a `git status` guard in `worktree`, a warning printed at
build time). This item is the one paragraph of brief text and its test,
nothing else.

Not the review or research briefs: neither runs in a builder's worktree,
and `_work/brieftext_review.tl` is out of scope.
