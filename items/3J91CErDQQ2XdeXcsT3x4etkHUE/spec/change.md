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
