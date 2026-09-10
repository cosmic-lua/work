## Evidence

Orchestrator session on 2026-09-10: bumped `bin/gitboard.pin` (stale
2026-09-07 release refused to read the board after its move to format
4), reconciled two `accepted`-but-unlanded items, then claimed,
worktreed, briefed and spawned 5 build agents for a fresh wave. Six
concrete places cost extra round-trips or wasted calls, none of them
caused by the spec content itself:

0. **Live reproduction of `5PCV_sHrL`'s exact premise, from the other
   side.** `gitboard claim`/`worktree --root /home/user/cosmic`
   silently captured local `main` (`32e7a711`, stuck ~107 commits
   behind, from a mid-session `git checkout -B` earlier that never
   touched `main` itself) instead of `origin/main` (`a44b020d`) —
   `git merge-base --is-ancestor 32e7a711 origin/main` fails outright,
   not just "behind." All 4 `cosmic-lua/cosmic` worktrees in this wave
   branched from the stale commit. One builder (`rs8c_for0`) correctly
   diagnosed its spec's cited feature (`--max-lines`, PR #1775,
   `5fc1aa41`) as absent from its worktree's history and stopped
   without committing — a false blocker: the feature is present and
   correct on real `origin/main`, just not reachable from the stale
   base it was handed. Cost: one full builder round (~103k tokens, 25
   tool calls) spent reaching a correct-sounding but wrong conclusion,
   plus re-doing claim/worktree/brief for that item once discovered.
   Neither `claim` nor `worktree` warn when the resolved local ref is
   behind its remote-tracking ref — exactly the gap `5PCV_sHrL`
   already names for the `done`-side verification half; this is the
   same defect biting the claim-time half, with a concrete second
   occurrence and cost figure to attach to that item.

1. **`session new` vs. the label `brief`/orchestrate print.**
   `gitboard help orchestrate` and every `brief KIND ID` verdict line
   ("claim it as `build-<handle>-<orch8>`") read as if that string is
   what `claim --session` wants. It is not: `claim`/`done`/etc. refuse
   anything but a 32-hex id from `gitboard session new`
   (`REFUSED: a claim needs a minted 32-hex session id`). Cost: one
   failed `claim` call per item before minting real sessions and using
   the printed label only as a bookkeeping name. This will recur for
   any orchestrator that follows the orchestrate doctrine literally.

2. **`done`/`claim` are two-phase but the phase is not signposted.**
   `gitboard done ID --landed SHA` prints `prepared …` / `publish: git
   push …` / `refresh refs: git fetch …` lines that read as already
   executed. Nothing is pushed until a separate `gitboard publish
   TXN --execute` (`done`'s own help never mentions `publish`), then
   `gitboard refresh --execute` to confirm — `refresh`'s help documents
   its own `--execute` but nothing on the `done`/`claim`/`publish` side
   says a second command is needed. Cost: for 2 landed items, several
   minutes spent reading raw remote refs with `git ls-remote` before
   noticing `publish` in the top-level verb list.

3. **`worktree --adopt`'s own recovery line omits the flag it needs.**
   A worktree bootstrap failure (missing `o/bootstrap/cosmic` — the
   same defect `RT7Y_NumT` already tracks; four of five worktrees in
   this wave hit it live) prints a recovery command with no repo flag:
   `gitboard worktree ID --adopt DIR --receipt-out FILE`. Running it
   bare fails asking for `--repo-dir`, but `--repo-dir` is not a valid
   option for `worktree` at all (`unknown option`) — the right flag is
   `--root`, used nowhere in the failure or recovery text. Cost: one
   dead-end call per recovery (4 in this wave) before finding `--root`
   by re-reading `help worktree`.

4. **A bare-title item sits undifferentiated among spec'd ones in
   `show`.** Four items surfaced as attractive-sounding board
   "standouts" from title alone (testrun's `.tests` grep, the dupes
   gate, `--docs` dropping `record`/`enum` fields, gate-denominator
   reporting) turned out to be `bar: spec: Change is missing or empty`
   — not pullable — discovered only on the pull attempt, after already
   naming them to the human as candidates. `[pullable]` is present in
   `show`'s row but easy to miss when scanning for interesting titles
   rather than filtering by it first.

## Non-goals

Not a request to change the doctrine's substance — the two-hour claim
lease, the prepare/publish/refresh split, and the session-mint
requirement are all working as designed. This is about the printed
strings not matching what the next command accepts.

## Update — the real cost of finding #0

Once all 5 builders in the wave reported, #0's true blast radius
became clear: **4 of 5 (all but `ha5l_jXYz`) branched from one of two
stale local `main`s** (`cosmic-lua/cosmic`'s at `32e7a711`, ~107
commits behind; `cosmic-lua/work`'s at a separate stale commit, ~100
commits behind — both from a `git checkout -B <branch>` earlier in the
session that created a new branch without ever fast-forwarding
`main` itself). Per-builder token/tool cost from each `Agent` call's
own usage report:

| item | tokens | tool calls | outcome |
|---|---|---|---|
| `rs8c_for0` | 102,711 | 25 | false blocker — spec's feature genuinely absent from the stale base, present and correct on real `main`; builder correctly stopped, but the diagnosis was wasted |
| `UqZn_jV6U` | 216,771 | 104 | full build completed against the stale base; needs a full redo |
| `jqgp_Bzmp` | 223,167 | 106 | full build completed against the stale base; needs a full redo |
| `dnMI_0WRU` | 208,275 | 109 | full build completed against the stale base; needs a full redo |
| `ha5l_jXYz` | 103,958 | 39 | only survivor — touched files happened to be untouched by the ~107 intervening commits |

~751k of ~855k total builder tokens across the wave were spent against
an avoidably wrong base. Worse, the obvious fix (cherry-pick each
builder's commit onto real `main`) is **not just a textual rebase**:
`cosmic-lua/cosmic`'s real `main` had independently deleted/restructured
`.cosmic-coverage` and `_build/public_surface_baseline.tl` underneath
the stale branch in the same commit range — the coverage-ratchet and
public-surface mechanisms both changed shape, so a clean cherry-pick
would have silently reintroduced dead tracking files rather than using
current main's actual (different) mechanism. Every affected item had to
be dropped and rebuilt from scratch against the corrected base, not
merely rebased.

One instance of `#0` should be board-fatal enough on its own to always
verify the resolved base before handing it to a builder — 4 confirmed
occurrences in one 5-item wave makes this the single highest-cost
defect found this session.

A second, compounding near-miss surfaced while attempting the
cherry-picks by hand: running `git checkout -b ...`/`cherry-pick` in a
worktree via a bare `cd <path> && git ...` Bash call, then a *later*
Bash call (after an intervening command auto-backgrounded past its
timeout, which silently did not carry its own `cd` forward) executed
follow-up `git checkout`/`branch -D` commands against the orchestrator's
own main checkout instead of the intended worktree — because shell cwd
is not guaranteed to persist across tool calls once a backgrounded
command intervenes. This briefly left the main checkout on a
builder's item branch (and its stale file contents) rather than the
orchestrator's own branch. No work was lost (caught immediately via a
"file changed on disk" notice and `git worktree list`), but the
countermeasure is procedural: every git operation against a worktree
should use `git -C <worktree-path>` explicitly, never a bare `cd` whose
persistence across tool calls cannot be relied on.
