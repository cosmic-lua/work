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
