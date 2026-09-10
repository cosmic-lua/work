## Evidence

A `gitboard worktree ID --fetch` preparation failure (the
`o/bootstrap/cosmic` defect `RT7Y_NumT` already tracks) prints an exact
recovery command carrying no repository flag at all:

```
$ grep -n "recovery: gitboard worktree" _work/gitworktree.tl
383:        adopt ~= nil and "" or ("; recovery: gitboard worktree %q --adopt %q --receipt-out FILE")
```

Run verbatim in a checkout with no `gitboard.repository` mapping — the
ordinary state of this environment (`git -C /home/user/work config
--local --get-all gitboard.repository` prints nothing) — it fails with
the shared resolver's refusal:

```
REFUSED: no local repository mapped for cosmic-lua/cosmic — configure one with
`git config --local --add gitboard.repository cosmic-lua/cosmic=/absolute/path` or pass --repo-dir
```

```
$ grep -n "or pass --repo-dir" _work/repository_map.tl
67:    .. "or pass --repo-dir"):format(repository, repository)
```

But `worktree` has no `--repo-dir`:

```
$ bin/gitboard worktree x4et_kHUE --repo-dir /tmp
unknown option: --repo-dir (try --help)
```

The flag `worktree` actually accepts is `--root`, and it is the only
verb that spells it that way — every other verb resolving the same
"local product checkout" concept says `--repo-dir`:

```
$ grep -n 'long = "root"' _work/gitcommands.tl
211:          {long = "root", arg = "DIR",
$ grep -n 'long = "repo-dir"' _work/gitcommands.tl
66:          {long = "repo-dir", arg = "DIR", help = "local product repository "
241:          {long = "repo-dir", arg = "DIR", help = "local product checkout; "
266:          {long = "repo-dir", arg = "DIR", help = "local product checkout; "
281:          {long = "repo-dir", arg = "DIR", help = "local product checkout; "
```

(claim:66, take:241, verdict:266, done:281 — all four resolve through the
same `_work/repository_map.tl` `resolve`, as `worktree` does at
`_work/gitworktree.tl:247` and `:337`.)

So the printed refusal names a flag that does not exist on the verb that
printed it, and the printed recovery command names no flag at all.

Reproduced live on 2026-09-10: 4 of 5 worktrees in one build wave hit the
underlying `RT7Y_NumT` bootstrap failure; the first recovery attempt on
each cost one dead-end `--repo-dir` call before `--root` was found by
re-reading `help worktree`.

## Change

One mechanism: **`worktree` adopts the name the other four verbs already
use.** Renaming `--root` to `--repo-dir` makes the shared resolver's
refusal (`_work/repository_map.tl:65-67`) true for every caller without
touching it, and gives the recovery line a real flag to echo.

**1. Rename the flag.** No alias and no deprecation branch: `unknown
option: --root (try --help)` is the whole migration.

- `_work/gitcommands.tl:211-213` — `{long = "root", arg = "DIR", help =
  "local product checkout override; otherwise use the configured
  repository mapping"}` becomes `{long = "repo-dir", ...}` with the help
  text made byte-identical to `take`'s at line 241 ("local product
  checkout; otherwise use the configured repository mapping"), so the
  five declarations read the same.
- `_work/gitcommands.tl:197` — the `worktree` `spec.summary` prose
  "Resolves ID's repo through the explicit repository map (or\n--root),
  creates" becomes "(or --repo-dir)".
- `_work/gitboard.tl:411` — `d.parsed.values["root"] or ""` becomes
  `d.parsed.values["repo-dir"] or ""`. This is the only dispatch site
  (`grep -n 'values\["root"\]' _work/gitboard.tl` → one hit); the file is
  476/500 lines, so make it a same-line edit and add nothing.
- Keep the Teal parameter name `root_override` in
  `_work/gitworktree.tl`'s `cmd_worktree` and `cmd_worktree_review`
  unchanged — it is a positional parameter, not the flag, and every test
  drives those functions directly (`_work/gitworktree_test.tl:139` and
  the ~20 sibling calls pass `checkout` positionally). Renaming it would
  churn four test files for nothing.
- Sweep the stale flag name out of the prose that quotes it. `grep -rn
  '\-\-root' _work docs README.md .github` today returns exactly these,
  and none of them is a live invocation:
  `_work/gitcommands.tl:197`, `_work/gitworktree.tl:3,231,294`,
  `_work/gitworktree_test.tl:3,32,35,74,312`,
  `_work/gitworktree_review_test.tl:35,78`. The `_work/gitworktree.tl`
  hits are the module header ("the `gitboard.repository` map or the
  explicit `--root` override") and two `@param root_override string
  `--root`, "" to auto-resolve` doc lines; the test hits are comments and
  `@return` doc lines. Re-run that grep after the edit — it must return
  no hit outside a deliberate historical note.

**2. Echo the flag in the recovery line.** `_work/gitworktree.tl:379-384`
today builds:

```
    return gate.verdict_line("worktree", false,
      ("checkout %s at %s; preparation failed: %s%s"):format(
        adopt ~= nil and "retained" or "created", path, referr,
        adopt ~= nil and "" or ("; recovery: gitboard worktree %q --adopt %q --receipt-out FILE")
        :format(id, path)))
```

`root_override` is in scope here (it is `cmd_worktree`'s fourth
parameter, used at line 337). Append ` --repo-dir %q` to the recovery
command when, and only when, the failing invocation itself supplied one —
a run that resolved through the configured map must not be told to pass a
flag it did not use, and a run that used an override must repeat it or
the recovery resolves a different checkout. Keep the rest of the string
byte-identical, `--adopt` and `--receipt-out FILE` included, and keep the
`adopt ~= nil and ""` guard that suppresses the whole clause on an
already-adopting run.

**3. Test.** `_work/gitworktree_bootstrap_test.tl` (385 lines, 115 under
the cap) is the file that can force this branch: its header states
"bootstrap programs are committed shell stubs", which is what makes a
preparation failure reachable without a network. Add one case that
drives `worktree.cmd_worktree` with a failing bootstrap stub, twice over
the same fixture:

- with a non-empty `root_override`, asserting the returned verdict line
  contains `--adopt`, `--receipt-out FILE`, and `--repo-dir` followed by
  that exact checkout path;
- with `root_override` empty (the configured-map path the file's
  neighbours already exercise), asserting the line contains `--adopt` and
  `--receipt-out FILE` and does NOT contain `--repo-dir`.

Assert in the same case that the verdict line never contains the string
`--root`, so the old name cannot come back through this path.

No `.cosmic-coverage` row moves: `_work/gitboard.tl` and
`_work/gitcommands.tl` change one token and one string each inside lines
already executed on every parse, and the new `_work/gitworktree.tl` branch
is the one the new test covers. If `--make ci` still reports a moved
`total`, hand-edit the one row it names, as README.md:262 directs, and do
not run `--make coverage --baseline` in this repo.

## Non-goals

- **`RT7Y_NumT` still owns the underlying bootstrap failure.** This item
  does not touch `_work/worktree_runtime.tl`, `o/bootstrap/cosmic`, or
  anything about why the fetch fails — only the recovery instruction the
  failure prints.
- **Do not change `_work/repository_map.tl`.** Making its refusal
  flag-aware (threading the caller's flag name through `resolve`) is the
  alternative to the rename and is rejected: it would leave two names for
  one concept and add a parameter to a resolver six call sites share. The
  rename makes the existing message correct as it stands, so lines 65-67
  keep their exact text.
- **`--root` keeps no alias.** Nothing in this repo invokes `worktree
  --root` (the sweep above finds only prose), and the board's briefs and
  `help orchestrate` name `worktree ID` with no repo flag at all, so a
  compatibility branch would be dead code from the day it lands.
- **The recovery line's other omissions stay out of scope.** It also omits
  `--session`, `--ref`, `--verbose` and `--fetch`; `--session` re-derives
  from the same environment on the retry (`_work/session.tl`'s ladder), and
  the rest change nothing about whether the recovery resolves a checkout.
  Echoing the full original argv is a separate question.
- **No verb gains or loses a flag.** `_work/gitcommands.tl` keeps the same
  five `--repo-dir`/`--root` declarations, one of them renamed; nothing is
  added to `_work/gitboard.tl`'s dispatch beyond the renamed lookup key.
